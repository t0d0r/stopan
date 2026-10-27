module Api
  module V1
    # Organizations with their mail settings, for administrators
    # (specs/admin.md, specs/organization-mail.md). Passwords are
    # write-only: a blank one keeps the stored password, none is returned.
    class OrganizationsController < BaseController
      MAIL_FIELDS = Admin::OrganizationsController::MAIL_FIELDS

      before_action :require_admin!
      before_action :set_organization, only: %i[show update destroy mail_test mailbox_check]

      def index
        organizations = Organization.ordered
        organizations = organizations.search(params[:q].to_s.squish.first(100)) if params[:q].present?
        render json: { organizations: organizations.map { |organization| organization_json(organization) } }
      end

      def show
        render json: { organization: organization_json(@organization, full: true) }
      end

      def create
        organization = Organization.new(organization_params)
        return render_invalid(organization) unless organization.save

        render json: { organization: organization_json(organization, full: true) }, status: :created
      end

      def update
        return render_invalid(@organization) unless @organization.update(organization_params)

        render json: { organization: organization_json(@organization, full: true) }
      end

      def destroy
        return render_error(:invalid, :unprocessable_content, message: I18n.t("flash.organization_has_tickets", name: @organization.name)) unless @organization.destroy

        head :no_content
      end

      # A test email through the organization's SMTP to the token's user.
      def mail_test
        return render_error(:invalid, :unprocessable_content, message: I18n.t("flash.mail_test_disabled")) unless @organization.smtp_ready?

        OrganizationMailer.with(organization: @organization, recipient: current_user).test_email.deliver_now
        render json: { sent_to: current_user.email }
      rescue StandardError => e
        render_error(:invalid, :bad_gateway, message: I18n.t("flash.mail_test_failed", error: e.message.truncate(200)))
      end

      # Logs in to the mailbox and counts unseen mail, taking none in.
      def mailbox_check
        return render_error(:invalid, :unprocessable_content, message: I18n.t("flash.mailbox_disabled")) unless @organization.imap_ready?

        render json: { unseen: MailboxCheck.new(@organization).probe }
      rescue StandardError => e
        render_error(:invalid, :bad_gateway, message: I18n.t("flash.mailbox_failed", error: e.message.truncate(200)))
      end

      private

      def set_organization
        @organization = Organization.find(params[:id])
      end

      def organization_params
        params.expect(organization: [ :name, :notes, :slug, :public_form, :public_intro, :public_allowed_senders,
                                      *MAIL_FIELDS ]).tap do |permitted|
          %i[smtp_password imap_password].each { |name| permitted.delete(name) if permitted[name].blank? }
        end
      end
    end
  end
end
