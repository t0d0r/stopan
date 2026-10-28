require "test_helper"

# The account pages and the password reset email must be fully Bulgarian
# when the browser asks for Bulgarian: no English fallbacks from Devise's
# own views and no missing translations (specs/auth.md).
class AccountPagesBulgarianTest < ActionDispatch::IntegrationTest
  BG = { "Accept-Language" => "bg" }.freeze

  # Names that stay in Latin script: the brand, fixture data, and the
  # language switch's codes and names (specs/ui.md "Language").
  # Names and addresses are data, not text to translate (the account menu shows the email).
  ALLOWED_LATIN = [ "Stopan", "Anna Requester", "anna@example.com", "Acme Bakery", "English", "Deutsch", "EN", "BG", "DE",
                    "Notes", "Omarchy", "/api/v1", "JSON", "API" ].freeze

  setup { ActionMailer::Base.deliveries.clear }

  def with_registration(open)
    previous = Rails.configuration.x.registration_open
    Rails.configuration.x.registration_open = open
    yield
  ensure
    Rails.configuration.x.registration_open = previous
  end

  # Visible text plus the attributes a reader or screen reader gets.
  def page_text
    page = Nokogiri::HTML(response.body)
    page.css("script, style").each(&:remove)
    attributes = page.css("[aria-label], [title], [placeholder], input[type=submit]").flat_map do |node|
      [ node["aria-label"], node["title"], node["placeholder"], (node["value"] if node.name == "input") ]
    end
    ([ page.at("title")&.text, page.at("body").text ] + attributes).compact.join(" ")
  end

  def assert_bulgarian_page
    assert_response :success
    text = page_text
    assert_no_match(/translation missing/i, response.body)
    ALLOWED_LATIN.each { |name| text = text.gsub(name, "") }
    latin = text.scan(/[A-Za-z]{2,}/).uniq
    assert_empty latin, "English left on #{request.path}: #{latin.join(', ')}"
  end

  test "sign-in, sign-up and forgot-password pages are Bulgarian" do
    with_registration(true) do
      [ new_user_session_path, new_user_registration_path, new_user_password_path ].each do |path|
        get path, headers: BG
        assert_bulgarian_page
      end
    end
  end

  test "the reset password page from the email is Bulgarian" do
    token = users(:anna).send(:set_reset_password_token)
    get edit_user_password_path(reset_password_token: token), headers: BG
    assert_bulgarian_page
  end

  test "the own account page is Bulgarian" do
    sign_in users(:anna)
    get edit_user_registration_path, headers: BG
    assert_bulgarian_page
  end

  test "sign-up errors are Bulgarian" do
    with_registration(true) do
      post user_registration_path, headers: BG,
           params: { user: { email: "", password: "short", password_confirmation: "other" } }
      assert_response :unprocessable_entity
      assert_select ".form-errors__title", text: /поправете/
      assert_select ".form-errors li", text: /Имейл/
      assert_select ".form-errors li", text: "Потвърждение на паролата не съвпада с Парола"
      assert_no_match(/translation missing/i, response.body)
    end
  end

  test "sign-up stores the name" do
    with_registration(true) do
      post user_registration_path, headers: BG,
           params: { user: { name: "Петя Петрова", email: "petya@example.com",
                             password: "octarine1", password_confirmation: "octarine1" } }
    end
    assert_equal "Петя Петрова", User.find_by!(email: "petya@example.com").name
  end

  test "the password reset email follows the request language" do
    post user_password_path, headers: BG, params: { user: { email: "anna@example.com" } }
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "anna@example.com" ], mail.to
    assert_equal "Инструкции за нова парола", mail.subject

    html = mail.html_part.body.decoded
    text = mail.text_part.body.decoded
    [ html, text ].each do |body|
      assert_includes body, "Здравейте, Anna Requester!"
      assert_includes body, "Смяна на паролата"
      assert_includes body, "6 часа"
      assert_includes body, "/users/password/edit?reset_password_token="
      assert_no_match(/translation missing|Hello|Someone has requested/i, body)
    end
    assert_includes html, 'lang="bg"'
  end

  test "the password reset email is English by default" do
    post user_password_path, params: { user: { email: "anna@example.com" } }
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.text_part.body.decoded, "Hello Anna Requester,"
    assert_includes mail.text_part.body.decoded, "The link works for 6 hours."
  end

  test "an unknown email sends nothing and says the same as a known one" do
    post user_password_path, headers: BG, params: { user: { email: "nobody@example.com" } }
    assert_empty ActionMailer::Base.deliveries
    assert_redirected_to new_user_session_path
    follow_redirect!(headers: BG.dup)
    assert_includes response.body, "Ако имейл адресът ви е в базата данни"
  end
end
