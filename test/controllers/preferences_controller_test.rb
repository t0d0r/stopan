require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  test "remembers the theme and text size without sign in" do
    patch preferences_url, params: { theme: "dark" }, headers: { "Referer" => new_user_session_url }
    assert_redirected_to new_user_session_url
    patch preferences_url, params: { scale: "extra" }

    get new_user_session_url
    assert_select "html[data-theme=dark][data-scale=extra]"
    assert_select "button[name=scale][value=extra][aria-pressed=true]"
  end

  test "ignores unknown values" do
    patch preferences_url, params: { theme: "neon", scale: "huge", width: "giant" }
    get new_user_session_url
    assert_select "html[data-theme=''][data-scale=normal][data-width=normal]"
  end

  test "remembers the wide layout" do
    patch preferences_url, params: { width: "wide" }
    get new_user_session_url
    assert_select "html[data-width=wide]"
    patch preferences_url, params: { width: "normal" }
    get new_user_session_url
    assert_select "html[data-width=normal]"
  end

  test "the theme (look) is notes by default, omarchy when chosen, and unknown values are ignored" do
    get new_user_session_url
    assert_select "html[data-look=notes]"
    patch preferences_url, params: { look: "omarchy" }, headers: { "Referer" => edit_user_registration_url }
    assert_redirected_to edit_user_registration_url
    get new_user_session_url
    assert_select "html[data-look=omarchy]"
    patch preferences_url, params: { look: "neon" }
    get new_user_session_url
    assert_select "html[data-look=omarchy]"

    sign_in users(:anna)
    get edit_user_registration_url
    assert_select "form#look[action=?] select[name=look] option[selected][value=omarchy]", preferences_path, "Omarchy"
    assert_select "form#look select[name=look] option[value=notes]", "Notes"
  end

  test "the menu bar has the theme switch and text sizes" do
    sign_in users(:admin)
    get tickets_url
    assert_select ".menubar form.prefs button[name=theme][value=dark]"
    assert_select ".menubar form.prefs button[name=theme][value=light]"
    assert_select ".menubar form.prefs button[name=scale]", 3
    assert_select ".menubar form.prefs button.width-toggle[name=width][value=wide][aria-label='Wide layout']"
    assert_select ".menubar form.prefs button.width-toggle[name=width][value=normal]"
  end
end
