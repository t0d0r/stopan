require "test_helper"

# Choosing the language in the header or on the account page
# (specs/ui.md "Language").
class LanguageTest < ActionDispatch::IntegrationTest
  test "the header offers the other languages, signed in and out" do
    get new_user_session_url
    assert_select "html[lang=en]"
    assert_select ".menubar form.prefs button.language-switch", 2
    assert_select ".menubar form.prefs button.language-switch[name=locale][value=bg][title=Български]", "BG"
    assert_select ".menubar form.prefs button.language-switch[name=locale][value=de][title=Deutsch]", "DE"

    get new_user_session_url, headers: { "Accept-Language" => "bg" }
    assert_select "html[lang=bg]"
    assert_select ".menubar form.prefs button.language-switch[name=locale][value=en][title=English]", "EN"
    assert_select ".menubar form.prefs button.language-switch[value=de]", "DE"

    sign_in users(:agent)
    get tickets_url, headers: { "Accept-Language" => "de-DE,de;q=0.9" }
    assert_select "html[lang=de]"
    assert_select ".menubar form.prefs button.language-switch", 2
    assert_select ".menubar form.prefs button.language-switch[value=de]", 0
  end

  test "German is chosen like the others and used for emails" do
    anna = users(:anna)
    sign_in anna
    patch preferences_url, params: { locale: "de" }
    assert_equal %w[de de], [ anna.reload.language, anna.locale ]
    get edit_user_registration_url
    assert_select "html[lang=de]"
    assert_select "form#language select[name='user[language]'] option[selected]", "Deutsch"
  end

  test "the switch keeps the language in a cookie when signed out" do
    patch preferences_url, params: { locale: "bg" }, headers: { "Referer" => new_user_session_url }
    assert_redirected_to new_user_session_url
    get new_user_session_url, headers: { "Accept-Language" => "en" }
    assert_select "html[lang=bg]"

    # An unknown language changes nothing.
    patch preferences_url, params: { locale: "fr" }
    get new_user_session_url
    assert_select "html[lang=bg]"
  end

  test "signed in, the switch is the user's choice: other browsers and emails follow it" do
    anna = users(:anna)
    sign_in anna
    patch preferences_url, params: { locale: "bg" }, headers: { "Accept-Language" => "en" }
    assert_equal %w[bg bg], [ anna.reload.language, anna.locale ]

    cookies.delete(:locale)
    get tickets_url, headers: { "Accept-Language" => "en" }
    assert_select "html[lang=bg]"
    assert_equal "bg", anna.reload.locale, "the browser language no longer overwrites the email language"
  end

  test "the account page saves a language or goes back to the browser's" do
    anna = users(:anna)
    sign_in anna
    get edit_user_registration_url
    assert_select "form#language select[name='user[language]'] option[selected]", "Browser language"

    patch user_language_url, params: { user: { language: "bg" } }
    assert_redirected_to edit_user_registration_url
    assert_equal "Езикът е запазен.", flash[:notice]
    follow_redirect!
    assert_select "html[lang=bg]"
    assert_select "form#language select[name='user[language]'] option[selected]", "Български"

    patch user_language_url, params: { user: { language: "" } }, headers: { "Accept-Language" => "en" }
    assert_nil anna.reload.language
    assert_equal "Language saved.", flash[:notice]
    get tickets_url, headers: { "Accept-Language" => "en" }
    assert_select "html[lang=en]"
    assert_equal "en", anna.reload.locale, "the browser language is remembered again"
  end

  test "an impersonating admin switches only their own view" do
    anna = users(:anna)
    anna.update!(language: "en", locale: "en")
    sign_in users(:admin)
    post admin_user_impersonation_url(anna)
    patch preferences_url, params: { locale: "bg" }
    get tickets_url
    assert_select "html[lang=bg]"
    assert_equal "en", anna.reload.language

    patch user_language_url, params: { user: { language: "bg" } }
    assert_response :forbidden
    assert_equal "en", anna.reload.language
  end
end
