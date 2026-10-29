module Admin
  # The Google setup wizard (specs/mail-oauth.md "Setup wizard"): from the
  # kind of Google account to a connected mailbox, either through an OAuth
  # client (connecting goes through MailOauthController) or with an app
  # password ("App password path").
  class GoogleSetupController < BaseController
    OAUTH_STEPS = %w[account project access client connect done].freeze
    APP_PASSWORD_STEPS = %w[account app_password mailbox saved].freeze
    FLOWS = { "workspace" => OAUTH_STEPS, "app_password" => APP_PASSWORD_STEPS, "gmail" => OAUTH_STEPS }.freeze
    KINDS = FLOWS.keys.freeze
    # One partial per step, chosen from this list, never from a parameter.
    STEP_PARTIALS = (OAUTH_STEPS | APP_PASSWORD_STEPS).index_with { |step| "admin/google_setup/step_#{step}" }.freeze

    before_action :require_super_admin
    before_action :set_wizard

    def show
      # Steps after the client need a saved client.
      @step = "client" if OAUTH_STEPS.index(@step).to_i > OAUTH_STEPS.index("client") && !@setting.google_ready?
      prepare_step
    end

    def update
      @step = "client"
      @steps = OAUTH_STEPS
      if @setting.update(client_params)
        redirect_to admin_google_setup_path(step: "connect"), notice: t("flash.google_client_saved")
      else
        render :show, status: :unprocessable_content
      end
    end

    def mailbox
      @step = "mailbox"
      @steps = APP_PASSWORD_STEPS
      @app_password = GmailAppPassword.new(app_password_params)
      if @app_password.save
        redirect_to admin_google_setup_path(step: "saved"),
                    notice: t("flash.gmail_app_password_saved", organization: @app_password.organization.name)
      else
        prepare_step
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_wizard
      @kind = params[:kind].presence_in(KINDS) || session[:google_setup_kind].presence_in(KINDS) || "workspace"
      step = params[:step].to_s
      # A step of the other path switches to it (the OAuth callback returns to connect and done).
      @kind = "workspace" if @kind == "app_password" && step.in?(OAUTH_STEPS - APP_PASSWORD_STEPS)
      @kind = "app_password" if step.in?(APP_PASSWORD_STEPS - OAUTH_STEPS)
      session[:google_setup_kind] = @kind
      @steps = FLOWS.fetch(@kind)
      # Choosing the kind on the first step moves on to the path's next step.
      step = @steps.second if step.blank? && params[:kind].in?(KINDS)
      @step = step.presence_in(@steps) || @steps.first
      @setting = AppSetting.current
    end

    def prepare_step
      @organizations = Organization.includes(:mail_connection).order(:name) if @step.in?(%w[connect done mailbox])
      @app_password ||= GmailAppPassword.new if @step == "mailbox"
      @gmail_organizations = GmailAppPassword.organizations if @step == "saved"
    end

    # The secret is write-only: a blank field keeps the stored one.
    def client_params
      params.expect(app_setting: %i[google_client_id google_client_secret])
            .tap { |permitted| permitted.delete(:google_client_secret) if permitted[:google_client_secret].blank? }
    end

    def app_password_params
      params.expect(gmail_app_password: %i[organization_id email app_password])
    end
  end
end
