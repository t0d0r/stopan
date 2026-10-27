require "test_helper"

# Outgoing mail through the organization's SMTP (specs/organization-mail.md
# "Outgoing mail").
class OrganizationRoutingTest < ActionMailer::TestCase
  setup do
    @ticket = tickets(:printer)
    @event = @ticket.add_comment(author: users(:agent), body: "Try a new roll.").event
  end

  def notification
    TicketMailer.with(recipient: users(:anna), ticket: @ticket, event_ids: [ @event.id ]).replied
  end

  test "without organization SMTP the global settings and sender are used" do
    mail = notification
    assert_equal [ Devise.mailer_sender ], mail.from
    assert_nil mail.reply_to
    assert_nil mail.delivery_method.settings[:address]
  end

  test "an organization's SMTP, From and Reply-To are used for its tickets" do
    @ticket.organization.update!(smtp_enabled: true, smtp_address: "smtp.acme.example", mail_from: "Acme Support <support@acme.example>",
                                 imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                                 mailbox_address: "support@acme.example")
    mail = notification
    mail.deliver_now
    assert_equal [ "support@acme.example" ], mail.from
    assert_equal [ "support@acme.example" ], mail.reply_to
    assert_equal "smtp.acme.example", mail.delivery_method.settings[:address]
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "without any SMTP a message is dropped" do
    Rails.configuration.x.global_smtp = false
    notification.deliver_now
    assert_empty ActionMailer::Base.deliveries
  ensure
    Rails.configuration.x.global_smtp = nil
  end

  test "a password reset uses the user's only organization with SMTP" do
    organizations(:acme).update!(smtp_enabled: true, smtp_address: "smtp.acme.example", mail_from: "support@acme.example")
    users(:anna).send_reset_password_instructions
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "support@acme.example" ], mail.from
  end
end
