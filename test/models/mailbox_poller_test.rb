require "test_helper"

# Automatic fetching, switched on in /admin/settings (specs/organization-mail.md "Fetching").
class MailboxPollerTest < ActiveSupport::TestCase
  setup { MailboxPoller.reset }
  teardown { MailboxPoller.reset }

  test "does nothing while fetching is off" do
    AppSetting.current.update!(mailbox_polling: false)
    assert_not MailboxPoller.tick
  end

  test "checks when on, then waits for the chosen interval, read afresh on every tick" do
    AppSetting.current.update!(mailbox_polling: true, mailbox_poll_seconds: 120)
    start = Time.current
    assert MailboxPoller.tick(start)
    assert_not MailboxPoller.tick(start + 90.seconds)
    assert MailboxPoller.tick(start + 120.seconds)

    AppSetting.current.update!(mailbox_poll_seconds: 600)
    assert_not MailboxPoller.tick(start + 420.seconds)
    assert MailboxPoller.tick(start + 720.seconds)
  end

  test "the interval is one of the offered values" do
    setting = AppSetting.current
    assert_not setting.update(mailbox_poll_seconds: 5)
    assert setting.errors.include?(:mailbox_poll_seconds)
  end
end
