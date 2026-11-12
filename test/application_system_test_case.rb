require "test_helper"
require "capybara/cuprite"

# Browser tests of what only JavaScript does (specs/system-tests.md):
# headless Chrome through Cuprite. Without Chrome they are skipped.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  CHROME = [ ENV["CHROME_PATH"], "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
             "/Applications/Chromium.app/Contents/MacOS/Chromium", "/usr/bin/chromium", "/usr/bin/chromium-browser",
             "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable" ].compact.find { |path| File.executable?(path) }

  driven_by :cuprite, screen_size: [ 1280, 900 ],
                      options: { headless: true, browser_path: CHROME, js_errors: true, process_timeout: 30, timeout: 15 }

  setup do
    skip "no Chrome found (set CHROME_PATH)" unless CHROME
    Users::SessionsController::RATE_LIMIT_STORE.clear
    SharedTicketsController::RATE_LIMIT_STORE.clear
  end

  # Through the sign-in form, as a person does.
  def sign_in_as(user, password: "password")
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: password
    click_button "Sign in"
    assert_no_current_path new_user_session_path
  end
end
