# Decides who is emailed about one user action on a ticket and which email
# they get (specs/notifications.md). The events of one action are written
# in one transaction; they are collected on their ticket and handed over
# once, after the transaction commits.
class TicketNotifier
  def self.collect(event)
    batch = event.ticket.notification_batch
    if batch.empty?
      transaction = ActiveRecord::Base.current_transaction
      transaction.after_commit do
        events = batch.dup
        batch.clear
        new(event.ticket, events).deliver_later
      end
      transaction.after_rollback { batch.clear }
    end
    batch << event
  end

  # The email a recipient gets for the events they may see, or nil. The
  # mailer asks again at sending time.
  def self.kind_for(recipient, events)
    actions = events.map(&:action)
    if actions.include?("created") then :created
    elsif actions.include?("replied") then :replied
    elsif actions.include?("noted") then :noted
    elsif events.any? { |event| event.action == "assignee_changed" && event.to_value == recipient.id.to_s } then :assigned
    elsif events.any? { |event| event.action == "status_changed" && [ event.from_value, event.to_value ] != %w[new open] }
      :status_changed
    end
  end

  def initialize(ticket, events)
    @ticket = ticket
    @events = events
  end

  def deliver_later
    notifications.each do |recipient, kind|
      TicketMailer.with(recipient: recipient, ticket: @ticket, event_ids: @events.map(&:id)).public_send(kind).deliver_later
    end
  end

  # { recipient => kind } for this batch.
  def notifications
    candidates.each_with_object({}) do |user, result|
      next if user == actor || user.deactivated? || !Ticket.visible_to(user).exists?(@ticket.id)

      kind = self.class.kind_for(user, TicketEvent.visible_to(user).where(id: @events.map(&:id)).to_a)
      result[user] = kind if kind
    end
  end

  private

  def actor
    @events.first.actor
  end

  def candidates
    users = [ @ticket.requester, @ticket.assignee ]
    users += User.new_ticket_subscribers.to_a if @events.any? { |event| event.action == "created" }
    users.compact.uniq
  end
end
