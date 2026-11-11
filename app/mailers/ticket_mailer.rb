# Ticket notification emails (specs/notifications.md). TicketNotifier picks
# the recipient and the kind; this mailer checks again, at sending time,
# that the recipient may see the ticket and which of the events, and sends
# nothing when they may not.
class TicketMailer < ApplicationMailer
  helper :tickets, :markdown
  helper_method :notification_intro, :reply_hint, :reply_note, :customer_reason?

  # Emails to the requester and Cc leave a record in the ticket's history
  # (specs/notifications.md "Emails to the requester", specs/followers.md).
  before_deliver { @delivering = true }
  after_deliver :record_customer_mail
  rescue_from StandardError, with: :customer_mail_failed

  def created = notify
  def replied = notify
  def noted = notify
  def assigned = notify
  def status_changed = notify

  private

  def notify
    @recipient = params[:recipient]
    @ticket = params[:ticket]
    return if @recipient.deactivated? || !Ticket.visible_to(@recipient).exists?(@ticket.id)

    @events = TicketEvent.visible_to(@recipient).where(id: params[:event_ids]).includes(:actor, :comment).order(:id).to_a
    return if @events.empty?

    @kind = action_name
    @actor = @events.first.actor
    @comment = @events.find(&:comment_event?)&.comment
    @status_event = @events.find { |event| event.action == "status_changed" }
    @reason = notification_reason
    @leave_url = leave_url
    @share_link = @ticket.share_link_for(@recipient)
    @ticket_link = @share_link ? shared_ticket_url(@ticket.share_token) : ticket_url(@ticket)

    I18n.with_locale(@recipient.mail_locale(@ticket.organization)) do
      headers["References"] = "<ticket-#{@ticket.number}@#{default_url_options[:host]}>"
      mail to: @recipient.email, template_name: "notification",
           subject: t("mailer.ticket.subject", number: @ticket.number, kind: t("mailer.ticket.kinds.#{@kind}"),
                                               subject: @ticket.subject)
    end
  end

  def customer_mail?
    @_mail_was_called && @ticket && @recipient && @ticket.customer?(@recipient)
  end

  # Sent, or dropped because no outgoing mail server exists.
  def record_customer_mail
    return unless customer_mail?

    if message.perform_deliveries
      @ticket.record_customer_mail("mail_sent", @kind, @recipient.email)
    else
      @ticket.record_customer_mail("mail_skipped", @kind, @recipient.email, "no_smtp")
    end
  end

  # A failed email to the customer side is recorded and logged, not
  # retried; anything else fails as before.
  def customer_mail_failed(error)
    raise error unless @delivering && customer_mail?

    Rails.logger.warn("Email to a customer of ticket #{@ticket.number} failed: #{error.class}")
    @ticket.record_customer_mail("mail_failed", @kind, @recipient.email, "#{error.class.name.demodulize}: #{error.message}")
  end

  # One sentence on what happened, in the recipient's language.
  def notification_intro
    key = @kind == "created" ? "created_#{@reason.presence_in(%w[requester assignee]) || "subscriber"}" : @kind
    t("mailer.ticket.intro.#{key}", actor: @actor&.display_name || t("ui.timeline.system"),
                                    reference: @ticket.reference, requester: @ticket.requester.display_name,
                                    from: status_label(@status_event&.from_value), to: status_label(@status_event&.to_value))
  end

  # Where to answer: the email itself when the organization's mailbox is
  # its Reply-To, else the ticket page (specs/notifications.md "Footer").
  def reply_hint(status)
    t("mailer.ticket.#{replies_by_email? ? "hint_by_email" : "hint"}.#{status}")
  end

  def reply_note
    return t("mailer.ticket.no_reply") unless replies_by_email?

    t(customer_reason? ? "mailer.ticket.reply_by_email" : "mailer.ticket.reply_by_email_staff")
  end

  def replies_by_email?
    @ticket.organization.replies_by_email?
  end

  def status_label(status)
    t("ui.statuses.#{status}") if status
  end

  def notification_reason
    if @ticket.requester_id == @recipient.id then "requester"
    elsif @ticket.assignee_id == @recipient.id then "assignee"
    elsif @ticket.ticket_followers.exists?(user_id: @recipient.id) then @recipient.staff? ? "follower" : "cc"
    else "subscriber"
    end
  end

  # Followers and Cc may leave from the email (specs/followers.md "Leaving").
  def leave_url
    return unless @reason.in?(%w[follower cc])

    follower = @ticket.ticket_followers.find_by(user_id: @recipient.id)
    leave_link_url(follower.generate_token_for(:leave)) if follower
  end

  # The requester and Cc get the customer's wording (specs/followers.md).
  def customer_reason?
    @reason.in?(%w[requester cc])
  end
end
