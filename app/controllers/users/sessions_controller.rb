module Users
  # Sign-in attempts are limited per client address, on top of Devise's
  # lock per account (specs/auth.md "Rate limits").
  class SessionsController < Devise::SessionsController
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

    # Prepended, not `rate_limit`: Devise's own first callback already
    # checks the password, so the limit has to run before it. Otherwise a
    # blocked attempt would still sign in, or tell a right password from
    # a wrong one.
    prepend_before_action :limit_sign_in_attempts, only: :create

    private

    def limit_sign_in_attempts
      rate_limiting(
        to: 20, within: 5.minutes, by: -> { request.remote_ip }, store: RATE_LIMIT_STORE,
        name: nil, scope: controller_path,
        with: -> { redirect_to new_user_session_path, alert: too_many_message }
      )
    end

    # The request's language is not set yet this early; nobody is signed
    # in, so it comes from the cookie or the browser.
    def too_many_message
      locale = locale_from_cookie || locale_from_accept_language || I18n.default_locale
      I18n.with_locale(locale) { t("flash.sign_in_too_many") }
    end
  end
end
