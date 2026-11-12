require "application_system_test_case"

# specs/system-tests.md "Covered"
class DeskTest < ApplicationSystemTestCase
  test "sign in with the password shown, then reply to a ticket" do
    visit new_user_session_path
    fill_in "user_email", with: users(:agent).email
    fill_in "user_password", with: "password"
    assert_equal "password", find("#user_password")[:type]
    find("[data-password-toggle]").click
    assert_equal "text", find("#user_password")[:type]
    click_button "Sign in"

    visit ticket_path(tickets(:printer))
    assert_selector "h1", text: tickets(:printer).subject
    fill_in "comment_body", with: "Typed in a real browser."
    find("[data-composer-submit]").click
    assert_selector ".timeline .message", text: "Typed in a real browser."
    assert_equal "Typed in a real browser.", tickets(:printer).comments.order(:id).last.body
  end

  test "stop sharing asks in the app's dialog; cancel keeps the link" do
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent))
    sign_in_as users(:agent)
    visit ticket_path(ticket)

    within("#sharing") { click_button "Stop sharing" }
    assert_selector "dialog[open] [data-confirm-title]", text: "Stop sharing this ticket?"
    within("dialog[open]") { click_button "Cancel" }
    assert_no_selector "dialog[open]"
    assert ticket.reload.shared?

    within("#sharing") { click_button "Stop sharing" }
    within("dialog[open]") { find("[data-confirm-ok]").click }
    within("#sharing") { assert_button "Create share link" }
    assert_not ticket.reload.shared?
  end

  test "report filters apply at once; a custom range shows its dates" do
    sign_in_as users(:agent)
    visit reports_path
    assert_no_selector "input[type=date]"

    select "Last 7 days", from: "period"
    assert_current_path(/period=7d/)
    assert_selector "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group]", count: 7

    select "Custom range", from: "period"
    assert_selector "input[type=date][name=from]"
    from = (Date.current - 2).iso8601
    find("input[name=from]").set(Date.current - 2)
    click_button "Apply"
    assert_current_path(/from=#{from}/)
    assert_selector "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group]", count: 3
  end

  test "the mail view has tabs that switch between the frame and the text" do
    ticket = tickets(:printer)
    ticket.update_columns(mail_html: "<p>Hello from <b>mail</b></p>" + ("<p>line</p>" * 30))
    sign_in_as users(:agent)
    visit ticket_path(ticket)

    assert_selector "[data-mail-tabs] [data-mail-tab=html][aria-selected=true]"
    assert_selector "iframe.mail-frame"
    assert_no_selector "#mail-pane-text"
    assert_operator find("iframe.mail-frame").native.node.evaluate("this.offsetHeight"), :>, 400
    within_frame(find("iframe.mail-frame")) { assert_selector "b", text: "mail" }

    find("[data-mail-tab=text]").click
    assert_selector "#mail-pane-text", text: ticket.description.first(20)
    assert_no_selector "iframe.mail-frame"
  end

  test "a password link asks, opens and counts one view" do
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent), password: "s3cret!")
    visit shared_ticket_path(ticket.share_token)
    assert_selector "h1", text: "This ticket is protected"
    assert_equal 0, ticket.reload.share_views

    fill_in "password", with: "s3cret!"
    click_button "Open"
    assert_selector "h1", text: ticket.subject
    assert_equal 1, ticket.reload.share_views
    visit shared_ticket_path(ticket.share_token)
    assert_selector "h1", text: ticket.subject
    assert_equal 1, ticket.reload.share_views
  end
end
