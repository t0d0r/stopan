require "test_helper"

# Every page renders in German without a missing translation (the test
# environment raises on one) and with German text (specs/ui.md
# "Translations").
class GermanPagesTest < ActionDispatch::IntegrationTest
  DE = { "Accept-Language" => "de" }.freeze

  setup { ActionMailer::Base.deliveries.clear }

  def assert_german(path)
    get path, headers: DE
    assert_response :success, "#{path} did not render"
    assert_select "html[lang=de]"
    assert_no_match(/translation missing|Translation missing/i, response.body, path)
  end

  test "staff pages" do
    sign_in users(:admin)
    ticket = tickets(:printer)
    [ tickets_path, tickets_path(view: "done"), board_path, ticket_path(ticket), new_ticket_path,
      notifications_path, edit_user_registration_path, admin_root_path, admin_users_path,
      new_admin_user_path, edit_admin_user_path(users(:anna)), admin_organizations_path,
      admin_organization_path(organizations(:acme)), new_admin_organization_path,
      edit_admin_organization_path(organizations(:acme)), new_admin_message_path, admin_settings_path ].each do |path|
      assert_german path
    end
    get tickets_path, headers: DE
    assert_select "h1", "Warteschlange"
  end

  test "requester pages" do
    sign_in users(:anna)
    [ tickets_path, tickets_path(view: "organization"), ticket_path(tickets(:printer)), new_ticket_path,
      edit_user_registration_path ].each do |path|
      assert_german path
    end
  end

  test "pages without sign-in" do
    organizations(:acme).update!(public_form: true)
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent), password: nil)
    [ new_user_session_path, new_user_password_path, new_magic_link_path, public_request_path("acme"),
      shared_ticket_path(ticket.share_token) ].each do |path|
      assert_german path
    end
    get new_user_session_path, headers: DE
    assert_select "h2", "Anmelden"
    assert_select "input[type=submit][value=Anmelden]"
  end

  test "the password reset email is German" do
    post user_password_path, headers: DE, params: { user: { email: "anna@example.com" } }
    mail = ActionMailer::Base.deliveries.last
    [ mail.subject, mail.html_part.body.decoded, mail.text_part.body.decoded ].each do |part|
      assert_no_match(/translation missing|Hello|Someone has requested/i, part)
    end
    assert_includes mail.html_part.body.decoded, 'lang="de"'
  end

  test "a ticket email to a German user is German" do
    users(:anna).update_columns(locale: "de")
    ticket = tickets(:printer)
    perform_enqueued_jobs { ticket.add_comment(author: users(:agent), body: "Bitte neu starten.") }
    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ "anna@example.com" ] }
    assert mail, "no email to the requester"
    assert_match(/\[Stopan ##{ticket.number}\]/, mail.subject)
    assert_no_match(/translation missing/i, mail.html_part.body.decoded)
    assert_no_match(/translation missing/i, mail.text_part.body.decoded)
  end
end
