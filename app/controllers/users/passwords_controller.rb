module Users
  # Requests for a password reset email are limited per client address
  # and per address asked for (specs/auth.md "Rate limits").
  class PasswordsController < Devise::PasswordsController
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

    rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, name: "ip",
               with: -> { too_many }
    rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, name: "email",
               by: -> { params.dig(:user, :email).to_s.strip.downcase },
               with: -> { too_many }

    private

    def too_many
      redirect_to new_user_password_path, alert: t("flash.magic_too_many")
    end
  end
end
