# Ticket notification emails (specs/notifications.md). TicketNotifier picks
# the recipient and the kind; this mailer checks again, at sending time,
# that the recipient may see the ticket and which of the events, and sends
# nothing when they may not.
class TicketMailer < ApplicationMailer
  helper :tickets, :markdown
  helper_method :notification_intro

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

    I18n.with_locale(@recipient.locale.presence || I18n.default_locale) do
      headers["References"] = "<ticket-#{@ticket.number}@#{default_url_options[:host]}>"
      mail to: @recipient.email, template_name: "notification",
           subject: t("mailer.ticket.subject", number: @ticket.number, kind: t("mailer.ticket.kinds.#{@kind}"),
                                               subject: @ticket.subject)
    end
  end

  # One sentence on what happened, in the recipient's language.
  def notification_intro
    key = @kind == "created" ? "created_#{@reason}" : @kind
    t("mailer.ticket.intro.#{key}", actor: @actor&.display_name || t("ui.timeline.system"),
                                    reference: @ticket.reference, requester: @ticket.requester.display_name,
                                    from: status_label(@status_event&.from_value), to: status_label(@status_event&.to_value))
  end

  def status_label(status)
    t("ui.statuses.#{status}") if status
  end

  def notification_reason
    if @ticket.requester_id == @recipient.id then "requester"
    elsif @ticket.assignee_id == @recipient.id then "assignee"
    else "subscriber"
    end
  end
end
