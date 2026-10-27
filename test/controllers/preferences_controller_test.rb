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
    assert_select "form#look select[name=look] option[value=default]", "Site default (Notes)"
  end

  test "an administrator sets the theme for everyone; a browser's own choice wins until it goes back to the default" do
    sign_in users(:admin)
    get admin_settings_url
    assert_select "#site-look select[name='app_setting[default_look]'] option[selected][value=notes]"
    patch admin_settings_url, params: { app_setting: { default_look: "omarchy" } }
    assert_equal "omarchy", AppSetting.current.reload.default_look
    patch admin_settings_url, params: { app_setting: { default_look: "neon" } }
    assert_response :unprocessable_content
    assert_equal "omarchy", AppSetting.current.reload.default_look

    # Visitors get the site's theme.
    sign_out :user
    get new_user_session_url
    assert_select "html[data-look=omarchy]"

    sign_in users(:anna)
    patch preferences_url, params: { look: "notes" }
    get tickets_url
    assert_select "html[data-look=notes]"
    get edit_user_registration_url
    assert_select "form#look option[selected][value=notes]"
    assert_select "form#look option[value=default]", "Site default (Omarchy)"

    patch preferences_url, params: { look: "default" }
    get tickets_url
    assert_select "html[data-look=omarchy]"
    get edit_user_registration_url
    assert_select "form#look option[selected][value=default]"
  end

  test "the own account page is a grid of panels, not the narrow sign-in card (specs/ui.md)" do
    sign_in users(:agent)
    get edit_user_registration_url
    assert_select ".auth", 0
    assert_select "h1.desk__title", "Your account"
    assert_select ".account-page > .panel-columns > .panel-columns__column", 3
    assert_select ".panel-columns__column > section.account-panel", 5
    assert_select ".panel-columns__column:first-child > #profile-panel"
    assert_select ".account-page > section.account-panel--wide#api-tokens"
    assert_select ".account-page #profile-panel form input[name='user[email]']"
    assert_select ".account-page section.account-panel--wide#api-tokens"

    sign_in users(:anna)
    get edit_user_registration_url
    assert_select ".panel-columns__column > section.account-panel", 4, "no notifications panel for requesters"

    sign_out :user
    get new_user_session_url
    assert_select ".auth"
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
