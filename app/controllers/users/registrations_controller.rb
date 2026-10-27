module Users
  # Sign-up is closed when REGISTRATION_OPEN is false (the production
  # default); administrators then create users at /admin. Users edit their
  # own name, email and password, but cannot delete their account: ticket
  # history must keep its people (specs/auth.md).
  class RegistrationsController < Devise::RegistrationsController
    before_action :require_open_registration, only: %i[new create]
    before_action :configure_permitted_parameters

    def destroy
      redirect_to edit_user_registration_path, alert: t("flash.account_delete_disabled")
    end

    private

    # A requester created by the public form or the mailbox has never known
    # a password: they choose the first one without the current password
    # (specs/public-form.md).
    def update_resource(resource, params)
      return super if resource.password_chosen?

      params = params.except(:current_password)
      params = params.except(:password, :password_confirmation) if params[:password].blank?
      resource.password_chosen = true if params[:password].present?
      resource.update(params)
    end

    def require_open_registration
      return if Rails.configuration.x.registration_open

      redirect_to new_user_session_path, alert: t("flash.registration_closed")
    end

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
      devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
    end
  end
end
