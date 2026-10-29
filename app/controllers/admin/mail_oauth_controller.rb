module Admin
  # Connecting an organization's mail to a Google account
  # (specs/mail-oauth.md "Behaviour"): the authorization code flow with
  # PKCE and a one-time state kept in the session, the callback, and
  # disconnecting.
  class MailOauthController < BaseController
    STATE_TTL = 10.minutes

    def start
      organization = admin_scope.organizations.find(params[:organization_id])
      unless google_configured?
        # The OAuth client is set in the wizard, by super administrators.
        back = current_user.admin? ? admin_google_setup_path(step: "client") : admin_organization_path(organization)
        return redirect_to back, alert: t("flash.google_not_configured")
      end

      state = SecureRandom.urlsafe_base64(32)
      verifier = GoogleOauth.verifier
      session[:mail_oauth] = { "state" => state, "verifier" => verifier, "organization_id" => organization.id,
                               "expires_at" => STATE_TTL.from_now.to_i, "wizard" => params[:return_to] == "wizard" && current_user.admin? }
      redirect_to MailConnection.client.authorize_url(redirect_uri: admin_mail_oauth_callback_url, state: state, verifier: verifier),
                  allow_other_host: true
    end

    def callback
      pending = session.delete(:mail_oauth)
      unless pending && pending["expires_at"].to_i > Time.current.to_i &&
             ActiveSupport::SecurityUtils.secure_compare(pending["state"].to_s, params[:state].to_s)
        return redirect_to admin_organizations_path, alert: t("flash.google_state_invalid")
      end

      organization = admin_scope.organizations.find(pending["organization_id"])
      # From the setup wizard, back to it (specs/mail-oauth.md "Setup wizard").
      wizard = pending["wizard"]
      back = wizard ? admin_google_setup_path(step: "connect") : admin_organization_path(organization)
      return redirect_to back, alert: t("flash.google_denied") if params[:error].present? || params[:code].blank?

      account = MailConnection.client.exchange(code: params[:code], verifier: pending["verifier"],
                                               redirect_uri: admin_mail_oauth_callback_url)
      connect(organization, account)
      redirect_to (wizard ? admin_google_setup_path(step: "done") : admin_organization_path(organization)),
                  notice: t("flash.google_connected", email: account[:email])
    rescue GoogleOauth::Error => e
      Rails.logger.warn("Google mail connect for organization #{organization&.id} failed: #{e.message}")
      redirect_to(back || admin_organizations_path, alert: t("flash.google_failed"))
    end

    def destroy
      organization = admin_scope.organizations.find(params[:organization_id])
      organization.mail_connection&.disconnect!
      organization.update!(mail_auth: "password", smtp_enabled: false, imap_enabled: false)
      redirect_to admin_organization_path(organization), notice: t("flash.google_disconnected")
    end

    private

    def google_configured?
      AppSetting.current.google_ready?
    end

    # Stores the account and points both parts of the organization's mail
    # at Gmail, keeping a From name and mailbox address already set.
    def connect(organization, account)
      Organization.transaction do
        connection = organization.mail_connection || organization.build_mail_connection
        connection.forget_token if connection.persisted?
        connection.update!(provider: "google", email: account[:email], refresh_token: account[:refresh_token],
                           status: "connected", connected_at: Time.current, last_error: nil)
        connection.remember_token(account[:access_token], account[:expires_in]) if account[:access_token]
        organization.update!(
          mail_auth: "google", smtp_enabled: true, imap_enabled: true,
          smtp_address: "smtp.gmail.com", smtp_port: 587, smtp_security: "starttls", smtp_username: account[:email],
          smtp_password: nil, mail_from: organization.mail_from.presence || account[:email],
          imap_address: "imap.gmail.com", imap_port: 993, imap_ssl: true, imap_username: account[:email],
          imap_password: nil, mailbox_address: organization.mailbox_address.presence || account[:email]
        )
      end
    end
  end
end
