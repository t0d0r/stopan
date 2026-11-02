require "test_helper"

# Emails to the requester: the switch and the record in the history
# (specs/notifications.md "Emails to the requester").
class RequesterMailTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @ticket = tickets(:printer)
  end

  def mail_events
    @ticket.events.where(action: TicketEvent::MAIL_ACTIONS).order(:id).map { |e| [ e.action, e.from_value, e.to_value, e.detail ].compact }
  end

  def reply(body = "Please try a new roll.")
    perform_enqueued_jobs { @ticket.add_comment(author: users(:agent), body: body) }
  end

  test "an email to the requester is recorded with its address and kind" do
    reply
    assert_equal [ "anna@example.com" ], ActionMailer::Base.deliveries.map { |m| m.to.sole }
    assert_equal [ [ "mail_sent", "replied", "anna@example.com" ] ], mail_events
    event = @ticket.events.find_by(action: "mail_sent")
    assert event.internal?
    assert_nil event.actor
  end

  test "switched off, the requester gets the in-app notification but no email" do
    @ticket.switch_requester_mail!(false, actor: users(:agent))
    assert_equal [ [ "mail_switched", "on", "off" ] ], mail_events
    assert_equal users(:agent), @ticket.events.find_by(action: "mail_switched").actor

    assert_difference -> { Notification.where(user: users(:anna)).count }, 1 do
      reply
    end
    assert_empty ActionMailer::Base.deliveries
    assert_equal [ "mail_skipped", "replied", "anna@example.com", "switched_off" ], mail_events.last
    assert_not @ticket.reload.email_requester?

    @ticket.switch_requester_mail!(true, actor: users(:agent))
    @ticket.switch_requester_mail!(true, actor: users(:agent))
    assert_equal 1, @ticket.events.where(action: "mail_switched", to_value: "on").count
  end

  test "switched off, a ticket from email gets no share link for the email" do
    @ticket.update_columns(source: "email")
    @ticket.switch_requester_mail!(false, actor: users(:agent))
    reply
    assert_not @ticket.reload.shared?
  end

  test "without any outgoing mail server the email is recorded as not sent" do
    Rails.configuration.x.global_smtp = false
    reply
    assert_empty ActionMailer::Base.deliveries
    assert_equal [ [ "mail_skipped", "replied", "anna@example.com", "no_smtp" ] ], mail_events
  ensure
    Rails.configuration.x.global_smtp = nil
  end

  # A delivery method whose server refuses the login.
  class FailingDelivery
    def initialize(_settings) = nil
    def deliver!(_mail) = raise(IOError, "535 bad credentials")
  end
  ActionMailer::Base.add_delivery_method :failing, FailingDelivery

  test "a failed email to the requester is recorded, not raised" do
    ActionMailer::Base.delivery_method = :failing
    reply
    action, kind, address, error = mail_events.sole
    assert_equal %w[mail_failed replied anna@example.com], [ action, kind, address ]
    assert_equal "IOError: 535 bad credentials", error
  ensure
    ActionMailer::Base.delivery_method = :test
  end

  test "emails to staff leave no record, and mail events notify nobody" do
    @ticket.update_columns(assignee_id: users(:agent_two).id)
    perform_enqueued_jobs { @ticket.add_comment(author: users(:anna), body: "Still blank.") }
    assert_equal [ "petar@example.com" ], ActionMailer::Base.deliveries.map { |m| m.to.sole }
    assert_empty mail_events

    ActionMailer::Base.deliveries.clear
    assert_no_difference -> { Notification.count } do
      perform_enqueued_jobs { @ticket.switch_requester_mail!(false, actor: users(:agent)) }
    end
    assert_empty ActionMailer::Base.deliveries
  end
end
