# Ends an impersonation and signs the administrator back in
# (specs/admin.md "Impersonation").
class ImpersonationsController < ApplicationController
  def destroy
    admin = impersonator
    user = current_user
    return redirect_to(root_path) unless admin

    Impersonation.where(id: session[:impersonation_id], ended_at: nil).update_all(ended_at: Time.current)
    Rails.logger.info("Impersonation #{session[:impersonation_id]}: admin #{admin.id} returned")
    session.delete(:impersonator_id)
    session.delete(:impersonation_id)
    bypass_sign_in(admin)
    redirect_to edit_admin_user_path(user), notice: t("flash.impersonation_stopped")
  end
end
