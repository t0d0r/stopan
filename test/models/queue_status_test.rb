require "test_helper"

# specs/status.md "Job queue"
class QueueStatusTest < ActiveSupport::TestCase
  test "jobs are named in plain terms, never with their arguments" do
    mail = { "arguments" => [ "TicketMailer", "replied", "deliver_now", { "params" => { "recipient" => "gid://stopan/User/7" } } ] }
    assert_equal "TicketMailer replied", QueueStatus.name_of("MailDeliveryJob", mail)
    assert_equal "TicketMailer replied", QueueStatus.name_of("ActionMailer::MailDeliveryJob", mail)

    hook = { "arguments" => [ 3, "ticket.created", '{"ticket":{"subject":"secret"}}' ] }
    assert_equal "Webhook ticket.created", QueueStatus.name_of("WebhookDeliveryJob", hook)

    assert_equal "Turbo::Streams::BroadcastStreamJob",
                 QueueStatus.name_of("Turbo::Streams::BroadcastStreamJob", { "arguments" => [ "stream", { "content" => "private text" } ] })
    assert_equal "MailDeliveryJob", QueueStatus.name_of("MailDeliveryJob", nil)
    assert_equal "MailDeliveryJob", QueueStatus.name_of("MailDeliveryJob", { "arguments" => [ { "x" => 1 } ] })

    [ mail, hook ].each do |arguments|
      name = QueueStatus.name_of("MailDeliveryJob", arguments) + QueueStatus.name_of("WebhookDeliveryJob", arguments)
      assert_no_match(/gid:|secret|User\/7/, name)
    end
  end

  test "outside production there is no queue to read" do
    assert_not QueueStatus.available?
    assert_nil QueueStatus.current
    assert_nil QueueStatus.clean
  end
end
