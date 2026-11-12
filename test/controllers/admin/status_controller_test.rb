require "test_helper"

# specs/status.md
class Admin::StatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk", imap_password: "pw",
                 mailbox_address: "support@acme.example")
  end

  test "super administrators see the mailboxes, the mail log, the queue note and the webhooks" do
    @org.update_columns(imap_last_checked_at: 2.minutes.ago, imap_messages_count: 3, imap_last_error: "Net::IMAP::NoResponseError: bad login")
    MailboxEvent.record(@org, result: "ticket", sender: "ivan@example.com", subject: "Slicer jams", ticket: tickets(:printer))
    MailboxEvent.record(@org, result: "ignored", reason: "staff_sender_without_a_ticket", sender: users(:agent).email, subject: "Test")
    MailboxEvent.record(@org, result: "failed", reason: "ActiveRecord::RecordInvalid", sender: "x@example.com", subject: "<b>bold</b>")
    hook = @org.webhooks.create!(url: "https://hooks.example.com/x", event_names: Webhook::EVENTS)
    hook.update_columns(failures: 20, active: false, last_error: "timeout")

    sign_in users(:admin)
    get admin_status_url
    assert_response :success
    assert_select ".admin-tabs a[aria-current=page][href=?]", admin_status_path, "Status"
    assert_select "#mail .status-line", /Automatic fetching is off/
    assert_select "##{ActionView::RecordIdentifier.dom_id(@org, :mailbox)}" do
      assert_select "td.num", "3"
      assert_select "td.mail-error", /bad login/
      assert_select "form[action=?]", mailbox_check_admin_organization_path(@org)
    end
    assert_select "#mail-log tbody tr", 3
    assert_select "#mail-log tr.status-row--failed td:last-child", "Failed: ActiveRecord::RecordInvalid"
    assert_select "#mail-log tr.status-row--failed td", "<b>bold</b>"
    assert_select "#mail-log tr.status-row--ignored td:last-child", /Ignored: sent by a staff member without a ticket/
    assert_select "#mail-log tr.status-row--ignored td", users(:agent).email
    assert_select "#mail-log tr.status-row--ticket td:last-child a[href=?]", ticket_path(tickets(:printer)), "New ticket #{tickets(:printer).reference}"
    assert_select "#jobs .panel__empty", /jobs run inside the web process/
    assert_select "##{ActionView::RecordIdentifier.dom_id(hook, :problem)}", /switched off after failing: timeout/

    AppSetting.current.update!(mailbox_polling: true, mailbox_poll_seconds: 300)
    get admin_status_url, headers: { "Accept-Language" => "bg" }
    assert_select "#mail .status-line", /на всеки 5 мин/
    assert_select "#mail-log tr.status-row--ignored td:last-child", /Игнорирано: изпратено от служител/
  end

  test "an empty desk says so" do
    @org.update!(imap_enabled: false)
    sign_in users(:admin)
    get admin_status_url
    assert_select "#mail .panel__empty", /No organization has a mailbox/
    assert_select "#mail .panel__empty", /No message has been taken in yet/
    assert_select "#webhook-problems .panel__empty", "All webhooks deliver."
  end

  test "the dashboard warns about a mailbox error and a switched-off webhook" do
    sign_in users(:admin)
    get admin_root_url
    assert_select ".status-warning", 0

    @org.update_columns(imap_last_error: "boom")
    @org.webhooks.create!(url: "https://hooks.example.com/x", event_names: Webhook::EVENTS).update_columns(failures: 20, active: false)
    get admin_root_url
    assert_select ".status-warning li", 2
    assert_select ".status-warning li", /1 mailbox has an error/
    assert_select ".status-warning li a[href=?]", admin_status_path
  end

  test "organization administrators, agents and requesters cannot open it or touch jobs" do
    Membership.find_by!(user: users(:agent), organization: @org).update!(admin: true)
    sign_in users(:agent)
    get admin_status_url
    assert_response :redirect
    get admin_organizations_url
    assert_select ".admin-tabs a[href=?]", admin_status_path, 0
    post retry_job_admin_status_url(id: 1)
    assert_response :redirect
    delete discard_job_admin_status_url(id: 1)
    assert_response :redirect

    sign_in users(:anna)
    get admin_status_url
    assert_response :redirect
  end

  test "job buttons say the queue cannot be read where there is none" do
    sign_in users(:admin)
    post retry_job_admin_status_url(id: 1)
    assert_redirected_to admin_status_url
    assert_equal "The job queue cannot be read here.", flash[:alert]
  end
end
