module Admin
  # Starts an impersonation (specs/admin.md "Impersonation"): the admin's id
  # stays in the session and the user is signed in without touching their
  # own sign-in times.
  class ImpersonationsController < BaseController
    def create
      user = User.find(params[:user_id])
      raise NotAuthorized unless Impersonation.allowed?(current_user, user)

      admin = current_user
      record = Impersonation.create!(admin: admin, user: user, started_at: Time.current, ip: request.remote_ip)
      Rails.logger.info("Impersonation #{record.id}: admin #{admin.id} signed in as user #{user.id}")
      bypass_sign_in(user)
      session[:impersonator_id] = admin.id
      session[:impersonation_id] = record.id
      redirect_to root_path, notice: t("flash.impersonation_started", name: user.display_name)
    end
  end
end
