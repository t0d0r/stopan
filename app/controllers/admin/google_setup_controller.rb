module Admin
  # The Google setup wizard (specs/mail-oauth.md "Setup wizard"): six steps
  # from the Google account type to a connected mailbox. Only the OAuth
  # client is saved here; connecting goes through MailOauthController.
  class GoogleSetupController < BaseController
    STEPS = 6
    KINDS = %w[workspace gmail].freeze
    # One partial per step, chosen from this list, never from a parameter.
    STEP_PARTIALS = (1..STEPS).map { |step| "admin/google_setup/step_#{step}" }.freeze

    before_action :set_wizard

    def show
      # Steps after the client need a saved client.
      @step = 4 if @step > 4 && !@setting.google_ready?
      @organizations = Organization.includes(:mail_connection).order(:name) if @step >= 5
    end

    def update
      @step = 4
      if @setting.update(client_params)
        redirect_to admin_google_setup_path(step: 5), notice: t("flash.google_client_saved")
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_wizard
      session[:google_setup_kind] = params[:kind] if params[:kind].in?(KINDS)
      @kind = session[:google_setup_kind].presence_in(KINDS) || "workspace"
      @step = params[:step].to_i.clamp(1, STEPS)
      @setting = AppSetting.current
    end

    # The secret is write-only: a blank field keeps the stored one.
    def client_params
      params.expect(app_setting: %i[google_client_id google_client_secret])
            .tap { |permitted| permitted.delete(:google_client_secret) if permitted[:google_client_secret].blank? }
    end
  end
end
