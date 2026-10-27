# Turns one email from an organization's mailbox into a ticket or a reply
# (specs/organization-mail.md "Processing a message"). The sender address
# is the identity, with the same rules as the public form.
class MailboxMessage
  REFERENCE = /\[Stopan #(\d+)\]/
  REFERENCE_HEADER = /<ticket-(\d+)@/
  SUBJECT_PREFIX = /\A\s*((re|fwd?|aw|wg|sv|отг|пре)\s*(\[\d+\])?\s*:\s*)+/i
  QUOTE_HEADER = /\A\s*(-{2,}\s*(original message|оригинално съобщение)\s*-{2,}|(on|на)\s.+(wrote|написа)\s*:)\s*\z/i
  SIGNATURE_IMAGE = 10.kilobytes

  attr_reader :organization, :mail

  def initialize(organization, raw)
    @organization = organization
    @mail = Mail.new(raw.to_s)
  end

  # :skipped (automatic or own mail), :ignored (sender may not), :ticket or
  # :reply.
  def process
    return :skipped if automatic? || sender.blank? || own_address?

    user = User.find_by("lower(email) = ?", sender)
    return ignore("deactivated sender") if user&.deactivated?
    return staff_reply(user) if user&.staff?

    ticket = referenced_ticket
    if ticket && user && ticket.requester_id == user.id
      reply(ticket, user)
    else
      new_ticket(user)
    end
  end

  private

  # Auto-responders, bounces and lists, so two robots never talk forever.
  def automatic?
    auto = mail.header["Auto-Submitted"]&.value.to_s.downcase
    return true if auto.present? && auto != "no"
    return true if %w[bulk junk list].include?(mail.header["Precedence"]&.value.to_s.downcase.strip)
    return true if mail.header["X-Autoreply"] || mail.header["X-Autorespond"] || mail.header["List-Id"]

    sender.to_s.start_with?("mailer-daemon@", "postmaster@") || mail.header["Return-Path"]&.value.to_s.strip == "<>"
  end

  def sender
    @sender ||= Array(mail.from).first.to_s.strip.downcase.presence
  end

  def own_address?
    [ organization.mail_from_address, organization.mailbox_address ].compact.map(&:downcase).include?(sender)
  end

  def referenced_ticket
    numbers = [ mail.subject.to_s[REFERENCE, 1], *references.filter_map { |ref| ref[REFERENCE_HEADER, 1] } ].compact
    organization.tickets.find_by(number: numbers.first) if numbers.any?
  end

  def references
    [ mail.header["In-Reply-To"], mail.header["References"] ].compact.flat_map { |field| field.value.to_s.split(/\s+/) }
  end

  # Staff may answer a ticket by email; they never start one this way.
  def staff_reply(user)
    ticket = referenced_ticket
    return ignore("staff sender without a ticket") unless ticket
    return ignore("agent outside the ticket's organization") unless Ticket.visible_to(user).exists?(ticket.id)

    reply(ticket, user)
  end

  def reply(ticket, user)
    files, rejected = attachments
    comment = ticket.add_comment(author: user, body: body_text(reply: true, rejected: rejected), files: files, source: "email")
    raise ActiveRecord::RecordInvalid, comment unless comment.persisted?

    :reply
  end

  def new_ticket(user)
    files, rejected = attachments
    created = false
    ticket = User.transaction do
      unless user
        user = User.create!(name: sender_name, email: sender, password: SecureRandom.base58(32), role: "requester",
                            password_chosen: false)
        created = true
      end
      Membership.find_or_create_by!(user: user, organization: organization)
      Ticket.create!(subject: ticket_subject, description: body_text(reply: false, rejected: rejected), files: files,
                     requester: user, organization: organization, actor: user, source: "email")
    end
    PublicRequestMailer.with(ticket: ticket).received.deliver_later if created
    :ticket
  end

  def ignore(reason)
    Rails.logger.info("Mailbox of organization #{organization.id}: message ignored (#{reason})")
    :ignored
  end

  def sender_name
    name = Array(mail[:from]&.display_names).first.to_s.strip
    (name.presence || sender.split("@").first).first(100)
  end

  def ticket_subject
    subject = mail.subject.to_s.sub(SUBJECT_PREFIX, "").squish
    (subject.presence || I18n.t("mailer.mailbox.no_subject")).first(200)
  end

  # The plain text, or the HTML as text; quotes cut from replies.
  def body_text(reply:, rejected:)
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    text = utf8(part&.decoded.to_s)
    text = html_to_text(text) if part&.mime_type == "text/html"
    text = text.gsub(/\r\n?/, "\n")
    text = without_quotes(text) if reply
    text = text.strip
    text = I18n.t("mailer.mailbox.no_text") if text.empty?
    text += "\n\n#{I18n.t("mailer.mailbox.rejected_files", names: rejected.join(", "))}" if rejected.any?
    text.first(20_000)
  end

  def utf8(text)
    text = text.dup.force_encoding(Encoding::UTF_8) unless text.encoding == Encoding::UTF_8
    text.valid_encoding? ? text : text.scrub("?")
  end

  def html_to_text(html)
    doc = Nokogiri::HTML5.fragment(html)
    doc.css("script, style, head").remove
    doc.css("br").each { |node| node.replace("\n") }
    doc.css("p, div, li, tr, h1, h2, h3, h4, h5, h6, blockquote").each { |node| node.add_next_sibling("\n") }
    doc.text.gsub(/\n{3,}/, "\n\n")
  end

  # Cuts the quoted earlier mail: from a "On ... wrote:" or "Original
  # Message" line, or from the first ">" line (with its attribution line).
  def without_quotes(text)
    lines = text.split("\n")
    cut = lines.index { |line| line.match?(QUOTE_HEADER) }
    quote = lines.index { |line| line.start_with?(">") }
    if quote && (cut.nil? || quote < cut)
      attribution = lines[0...quote].rindex { |line| line.strip.present? }
      quote = attribution if attribution && lines[attribution].strip.end_with?(":")
      cut = quote
    end
    (cut ? lines.first(cut) : lines).join("\n")
  end

  # Allowed files up to the limits; the names of the others.
  def attachments
    accepted = []
    rejected = []
    mail.attachments.each do |part|
      data = part.decoded
      next if part.inline? && part.mime_type.to_s.start_with?("image/") && data.bytesize < SIGNATURE_IMAGE

      name = part.filename.to_s.presence || "attachment"
      type = Marcel::MimeType.for(StringIO.new(data), name: name, declared_type: part.mime_type)
      if accepted.size < Attachable::MAX_FILES && data.bytesize <= Attachable::MAX_SIZE && Attachable::ALLOWED_TYPES.include?(type)
        accepted << { io: StringIO.new(data), filename: name, content_type: type }
      else
        rejected << name
      end
    end
    [ accepted, rejected ]
  end
end
