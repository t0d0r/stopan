require "test_helper"

# The composer's "Email the requester" toggle (specs/notifications.md
# "Emails to the requester").
class RequesterMailsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @ticket = tickets(:printer) }

  test "staff see the toggle and its warning while replying publicly" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#composer [data-requester-mail][data-path=?]", ticket_requester_mail_path(@ticket) do
      assert_select "input[type=checkbox][role=switch][name=email_requester][checked]"
      assert_select ".composer__mail-on", /anna@example.com will get public replies and status changes by email, outside Stopan/
    end

    @ticket.switch_requester_mail!(false, actor: users(:agent))
    get ticket_url(@ticket)
    assert_select "#composer .composer__mail.is-off input[role=switch]:not([checked])"
    assert_select ".timeline__text", "Maria Agent turned emails to the requester off"
  end

  test "requesters see no toggle and no mail events" do
    @ticket.record_requester_mail("mail_sent", "replied", "anna@example.com")
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "[data-requester-mail]", 0
    assert_no_match "Email to anna@example.com", response.body
  end

  test "the toggle saves at once, for staff who may update the ticket" do
    sign_in users(:agent)
    post ticket_requester_mail_url(@ticket), params: { _method: "patch", email_requester: "0" }
    assert_response :no_content
    assert_not @ticket.reload.email_requester?
    patch ticket_requester_mail_url(@ticket), params: { email_requester: "1" }
    assert @ticket.reload.email_requester?

    sign_in users(:anna)
    patch ticket_requester_mail_url(@ticket), params: { email_requester: "0" }
    assert_response :forbidden
    assert @ticket.reload.email_requester?

    sign_in users(:agent)
    memberships(:agent_acme).destroy
    patch ticket_requester_mail_url(@ticket), params: { email_requester: "0" }
    assert_response :not_found
  end

  test "without JavaScript the toggle comes with the reply and is saved first" do
    sign_in users(:agent)
    perform_enqueued_jobs do
      post ticket_comments_url(@ticket), params: { email_requester: "0", comment: { body: "Fixed.", internal: "0" } }
    end
    assert_not @ticket.reload.email_requester?
    assert_empty ActionMailer::Base.deliveries.select { |mail| mail.to == [ "anna@example.com" ] }
    get ticket_url(@ticket)
    assert_select ".timeline__text", /No email to the requester \(New reply\): emails are off for this ticket/

    # An internal note leaves the switch alone.
    post ticket_comments_url(@ticket), params: { email_requester: "1", comment: { body: "Note.", internal: "1" } }
    assert_not @ticket.reload.email_requester?
  end

  test "a sent email shows in the staff timeline" do
    sign_in users(:agent)
    perform_enqueued_jobs do
      post ticket_comments_url(@ticket), params: { email_requester: "1", comment: { body: "Try again.", internal: "0" } }
    end
    get ticket_url(@ticket)
    assert_select ".timeline__item--internal .timeline__text", "Email to anna@example.com: New reply"
  end
end
