module TicketsHelper
  include MarkdownHelper

  # Paper colour per status and priority; always shown with its text (ui.md).
  STATUS_COLORS = { "new" => "yellow", "open" => "pink", "pending" => "blue", "postponed" => "purple", "done" => "green" }.freeze
  PRIORITY_COLORS = { "low" => "gray", "normal" => "blue", "high" => "purple", "urgent" => "pink" }.freeze
  # Paper colour per list view (queues.md); pending and done match their statuses.
  VIEW_COLORS = { "unsolved" => "yellow", "mine" => "purple", "unassigned" => "pink", "pending" => "blue",
                  "done" => "green", "all" => "gray", "open" => "yellow", "organization" => "purple",
                  "postponed" => "purple" }.freeze
  AVATAR_COLORS = %w[yellow blue green pink purple gray].freeze

  def status_name(status)
    t("ui.statuses.#{status}")
  end

  def priority_name(priority)
    t("ui.priorities.#{priority}")
  end

  def status_pill(status)
    tag.span(status_name(status), class: "pill pill--status sticky--#{STATUS_COLORS.fetch(status, 'gray')}")
  end

  def priority_pill(priority)
    tag.span(priority_name(priority), class: "pill pill--priority pill--#{priority} sticky--#{PRIORITY_COLORS.fetch(priority, 'gray')}")
  end

  ADDRESS = %r{\bhttps?://[^\s<>"]+}i
  ADDRESS_LABEL_LENGTH = 48

  # Plain text with line breaks; HTML in the text is escaped, and web
  # addresses become links with a short label (specs/markdown.md "Plain
  # text links").
  def ticket_text(text)
    simple_format(link_addresses(text.to_s), { class: "ticket-text__p" }, sanitize: false)
  end

  MAIL_RULE = /\A\s*([-_=*])\1{2,}\s*\z/
  MAIL_SIGNATURE = /\A--\s?\z/

  # A message that came in by mail, laid out as mail: rules, quote blocks,
  # and a softer signature and newsletter footer (specs/organization-mail.md
  # "Display of mail"). Nothing is left out.
  def mail_text(text)
    lines = text.to_s.split("\n")
    signature_at = lines.index { |line| line.match?(MAIL_SIGNATURE) }
    signature = signature_at ? lines[(signature_at + 1)..] : []
    lines = lines.first(signature_at) if signature_at
    footer_at = lines.rindex { |line| line.match?(MAIL_RULE) }
    footer = footer_at && footer_at >= lines.size / 2 ? lines[(footer_at + 1)..] : []
    lines = lines.first(footer_at) if footer.any?

    parts = [ mail_blocks(lines) ]
    parts << tag.div(mail_blocks(footer), class: "mail-footer") if footer.join.strip.present?
    parts << tag.div(ticket_text(signature.join("\n")), class: "mail-signature") if signature.join.strip.present?
    safe_join(parts)
  end

  # Runs of text, rule and quote lines, each as its own block.
  def mail_blocks(lines)
    kind = ->(line) { line.match?(MAIL_RULE) ? :rule : (line.start_with?(">") ? :quote : :text) }
    blocks = lines.slice_when { |a, b| kind.(a) != kind.(b) }.filter_map do |run|
      case kind.(run.first)
      when :rule then tag.hr(class: "mail-rule")
      when :quote then tag.blockquote(ticket_text(run.map { |line| line.sub(/\A>\s?/, "") }.join("\n")), class: "mail-quote")
      else ticket_text(run.join("\n")) if run.join.strip.present?
      end
    end
    safe_join(blocks)
  end

  # The escaped text with each http(s) address as a link.
  def link_addresses(text)
    parts = []
    last = 0
    text.scan(ADDRESS) do
      match = Regexp.last_match
      address, rest = split_trailing_punctuation(match[0])
      parts << text[last...match.begin(0)] << address_link(address) << rest
      last = match.end(0)
    end
    parts << text[last..]
    safe_join(parts)
  end

  # Host without www. and path, without query string and fragment.
  def address_label(address)
    label = address.sub(%r{\Ahttps?://}i, "").sub(/\Awww\./i, "").split(/[?#]/, 2).first.to_s.chomp("/")
    truncate(label.presence || address, length: ADDRESS_LABEL_LENGTH, omission: "…")
  end

  def address_link(address)
    link_to address_label(address), address, rel: "noopener noreferrer nofollow", target: "_blank", data: { address: true }
  end

  # Sentence punctuation after an address, and a closing bracket without
  # its opening one, belong to the text around it.
  def split_trailing_punctuation(address)
    rest = +""
    loop do
      last = address[-1]
      closing = { ")" => "(", "]" => "[" }[last]
      break unless last.match?(/[.,;:!?'*]/) || (closing && address.count(closing) < address.count(last))

      rest.prepend(last)
      address = address[0...-1]
    end
    [ address, rest ]
  end

  # The current text of a request or comment, formatted when it is
  # Markdown (specs/markdown.md); used by pages and emails.
  def formatted_text(record, tasks: false)
    text = record.is_a?(Ticket) ? record.description : record.body
    record.markdown? ? render_markdown(text, tasks: tasks) : plain_text(record, text)
  end

  # Plain text, laid out as mail when the message came in by mail.
  def plain_text(record, text)
    record.source == "email" ? mail_text(text) : ticket_text(text)
  end

  # The message text as shown on a page; the copy box reads it. task_path:
  # where an editor's task list clicks go (specs/markdown.md "Task lists").
  def message_text(record, task_path: nil)
    tag.div(formatted_text(record, tasks: task_path.present?),
            class: [ "ticket-text", ("markdown-body" if record.markdown?) ],
            data: { message_text: true, task_path: task_path })
  end

  # The "Translate" button and translations show for staff when an
  # administrator switched them on and a DeepL key is set (translation.md).
  def translation_offered?
    return @translation_offered if defined?(@translation_offered)

    @translation_offered = user_signed_in? && current_user.staff? && Translation.available?
  end

  # A language named in the current UI language; DeepL may detect any.
  def language_name(code)
    t("ui.translation.languages.#{code}", default: code.to_s.upcase)
  end

  # "M" box in a message's title strip that switches Markdown on or off.
  def markdown_box(path, on:)
    label = on ? t("ui.markdown.turn_off") : t("ui.markdown.turn_on")
    button_to path, method: :patch, params: { markdown: on ? "0" : "1" }, form_class: "markdown-box__form",
                    class: "sticky__box sticky__box--icon markdown-box", title: label,
                    aria: { label: label, pressed: on } do
      icon(:markdown, size: 10)
    end
  end

  def user_name(user)
    user&.display_name || t("ui.timeline.system")
  end

  # One sentence for a property event, e.g. "Maria changed status from Open
  # to Pending".
  def event_sentence(event)
    actor = user_name(event.actor)
    case event.action
    when "created"
      source = event.ticket.source
      source == "app" ? t("ui.timeline.created", actor: actor) : t("ui.timeline.created_#{source}", actor: actor)
    when "status_changed"
      t("ui.timeline.status_changed", actor: actor, from: status_name(event.from_value), to: status_name(event.to_value))
    when "priority_changed"
      t("ui.timeline.priority_changed", actor: actor, from: priority_name(event.from_value),
                                         to: priority_name(event.to_value))
    when "assignee_changed"
      to = event.to_value.present? ? assignee_name(event.to_value) : nil
      to ? t("ui.timeline.assigned", actor: actor, to: to) : t("ui.timeline.unassigned", actor: actor)
    when "shared"
      event.to_value == "password" ? t("ui.timeline.shared_password", actor: actor) : t("ui.timeline.shared", actor: actor)
    when "unshared" then t("ui.timeline.unshared", actor: actor)
    when "stage_changed"
      if event.to_value.present? then t("ui.timeline.stage_changed", actor: actor, stage: event.to_value)
      else t("ui.timeline.stage_cleared", actor: actor, stage: event.from_value)
      end
    end
  end

  def event_icon(event)
    { "created" => :spark, "status_changed" => :status, "priority_changed" => :flag,
      "assignee_changed" => :user, "shared" => :link, "unshared" => :link, "stage_changed" => :flag }.fetch(event.action, :spark)
  end

  def assignee_name(user_id)
    @assignee_names ||= {}
    @assignee_names[user_id] ||= User.find_by(id: user_id)&.display_name || t("ui.timeline.removed_user")
  end

  # On a shared page (share_token) files go through the share link.
  # Round stamp on a card due to be postponed within a week, like Fizzy's
  # "closes in" (specs/board.md "Automatic postponing").
  def postpone_stamp(ticket)
    left = AutoPostpone.days_left(ticket, postpone_days)
    return unless left && left <= AutoPostpone::STAMP_DAYS

    label = left.zero? ? t("ui.board.stamp_today") : t("ui.board.stamp_days", count: left)
    tag.span(class: "postpone-stamp", title: label, aria: { label: label }) do
      tag.span(left.zero? ? t("ui.board.stamp_top_today") : t("ui.board.stamp_top"), class: "postpone-stamp__top") +
        tag.span(left.zero? ? t("ui.board.stamp_now") : left,
                 class: [ "postpone-stamp__number", ("postpone-stamp__number--word" if left.zero?) ]) +
        tag.span(left.zero? ? "" : t("ui.board.stamp_unit", count: left), class: "postpone-stamp__unit")
    end
  end

  # "Moves to Not now in 3 days" for staff on the ticket page.
  def postpone_note(ticket)
    left = AutoPostpone.days_left(ticket, postpone_days)
    return unless left && left <= AutoPostpone::STAMP_DAYS

    tag.p(left.zero? ? t("ui.board.note_today") : t("ui.board.note_days", count: left), class: "postpone-note")
  end

  def postpone_days
    @postpone_days ||= AutoPostpone.days
  end

  # "edited by Maria 5 minutes ago" on an edited request or comment
  # (specs/timeline.md "Editing").
  def edited_note(record)
    return unless record.edited?

    tag.span(class: "edited-tag") do
      safe_join([ t("ui.edit.edited_by", name: record.edited_by&.display_name), time_ago(record.edited_at) ], " ")
    end
  end

  # What an edit changed, word by word: removed words in <del>, added in
  # <ins> (specs/timeline.md "Editing").
  def diff_html(old_text, new_text)
    safe_join(TextDiff.diff(old_text, new_text).map do |kind, text|
      case kind
      when :del then tag.del(text)
      when :ins then tag.ins(text)
      else text
      end
    end)
  end

  # Copies the text of the message it sits in ([data-message-text]); shown
  # by application.js (specs/ui.md "Copy box").
  def copy_box
    tag.button(type: "button", class: "sticky__box sticky__box--icon copy-box", hidden: true,
               title: t("ui.copy.label"), aria: { label: t("ui.copy.label") },
               data: { copy_message: true, label: t("ui.copy.label"), copied: t("ui.copy.copied") }) do
      icon(:copy, size: 10) + tag.span(icon(:check, size: 10), class: "copy-box__done")
    end
  end

  # Pencil box that opens the edit form in place of the text (a Turbo frame).
  def edit_link(path, frame:)
    link_to path, class: "sticky__box sticky__box--icon edit-link", data: { turbo_frame: frame },
                  title: t("ui.edit.edit_hint"), aria: { label: t("ui.edit.edit") } do
      icon(:pencil, size: 10)
    end
  end

  # Live count of open shared pages of the ticket's link (specs/sharing.md
  # "Who is viewing now"); application.js swaps the text on each signal.
  # scope: :page (the shared page, counting the reader) or :panel.
  def share_viewers_tag(count, scope:)
    texts = %i[zero one other].filter_map do |key|
      [ key, t("ui.share.viewers.#{scope}.#{key}") ] if I18n.exists?("ui.share.viewers.#{scope}.#{key}")
    end.to_h
    tag.p(class: "share-viewers", data: { count: count }) do
      tag.span(class: "share-viewers__dot", aria: { hidden: true }) + icon(:eye, size: 13) +
        tag.span(t("ui.share.viewers.#{scope}", count: count), data: { share_viewers: true, **texts }, aria: { live: "polite" })
    end
  end

  # A download link that opens the preview dialog for previewable kinds
  # (specs/attachments.md "Preview"); modified clicks still download.
  def attachment_link(ticket, attachment, share_token: nil)
    path = share_token ? shared_ticket_file_path(share_token, attachment) : ticket_attachment_path(ticket, attachment)
    kind = Attachable.preview_kind(attachment.blob)
    preview = if kind
      share_token ? shared_ticket_file_preview_path(share_token, attachment) : preview_ticket_attachment_path(ticket, attachment)
    end
    data = { turbo: false, preview_item: true, preview_kind: kind || "none", preview_url: preview,
             filename: attachment.filename.to_s, details: number_to_human_size(attachment.byte_size) }
    link_to path, class: "file-link", data: data do
      icon(:clip) + tag.span(attachment.filename.to_s, class: "file-link__name") +
        tag.span(number_to_human_size(attachment.byte_size), class: "file-link__size")
    end
  end

  # Staff can pick the current status or an allowed transition.
  def status_options(ticket)
    current = ticket.status_was || ticket.status
    ([ current ] + Ticket::TRANSITIONS.fetch(current, [])).map { |status| [ status_name(status), status ] }
  end

  def priority_options
    Ticket::PRIORITIES.map { |priority| [ priority_name(priority), priority ] }
  end

  def staff_options(staff)
    staff.map { |user| [ user.display_name, user.id ] }
  end

  def queue_view_label(view)
    t("ui.queue.views.#{view}")
  end

  def view_color(view)
    VIEW_COLORS.fetch(view, "gray")
  end

  # Initials on a paper colour picked from the user id, so a person keeps
  # their colour. Decorative: the name is always shown next to it.
  def user_avatar(user)
    initials = user.display_name.split.first(2).map { |word| word[0] }.join.upcase
    tag.span(initials, class: "avatar sticky--#{AVATAR_COLORS[user.id % AVATAR_COLORS.size]}", "aria-hidden": "true")
  end
end
