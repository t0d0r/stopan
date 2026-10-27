module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show edit update destroy mail_test mailbox_check]

    def index
      @query = params[:q].to_s.squish.first(100).presence
      organizations = Organization.ordered
      organizations = organizations.search(@query) if @query
      @organizations = organizations
      @member_counts = Membership.group(:organization_id).count
      @ticket_counts = Ticket.group(:organization_id).count
      @unsolved_counts = Ticket.unsolved.group(:organization_id).count
    end

    def show
      @memberships = @organization.memberships.includes(:user).sort_by { |m| m.user.display_name.downcase }
      @candidates = User.active.where.not(id: @organization.memberships.select(:user_id)).ordered
      @ticket_count = @organization.tickets.count
      @unsolved_count = @organization.tickets.unsolved.count
    end

    def new
      @organization = Organization.new
    end

    def create
      @organization = Organization.new(organization_params)
      if @organization.save
        redirect_to admin_organization_path(@organization), notice: t("flash.organization_created", name: @organization.name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @organization.update(organization_params)
        redirect_to admin_organization_path(@organization), notice: t("flash.organization_updated", name: @organization.name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Sends a test email through the organization's SMTP to the signed-in
    # admin, right away, and reports the result.
    def mail_test
      unless @organization.smtp_enabled?
        return redirect_to admin_organization_path(@organization), alert: t("flash.mail_test_disabled")
      end

      OrganizationMailer.with(organization: @organization, recipient: current_user).test_email.deliver_now
      redirect_to admin_organization_path(@organization), notice: t("flash.mail_test_sent", email: current_user.email)
    rescue StandardError => error
      redirect_to admin_organization_path(@organization), alert: t("flash.mail_test_failed", error: error.message.truncate(200))
    end

    # Logs in to the organization's mailbox and reports the unseen count,
    # without taking any mail in.
    def mailbox_check
      unless @organization.imap_enabled?
        return redirect_to admin_organization_path(@organization), alert: t("flash.mailbox_disabled")
      end

      count = MailboxCheck.new(@organization).probe
      redirect_to admin_organization_path(@organization), notice: t("flash.mailbox_ok", count: count)
    rescue StandardError => error
      redirect_to admin_organization_path(@organization), alert: t("flash.mailbox_failed", error: error.message.truncate(200))
    end

    def destroy
      if @organization.destroy
        redirect_to admin_organizations_path, notice: t("flash.organization_deleted", name: @organization.name)
      else
        redirect_to admin_organization_path(@organization), alert: t("flash.organization_has_tickets", name: @organization.name)
      end
    end

    private

    def set_organization
      @organization = Organization.find(params[:id])
    end

    MAIL_FIELDS = %i[smtp_enabled smtp_address smtp_port smtp_security smtp_username smtp_password remove_smtp_password
                     mail_from imap_enabled imap_address imap_port imap_ssl imap_username imap_password
                     remove_imap_password imap_folder mailbox_address].freeze

    # Passwords are write-only: a blank field keeps the stored one
    # (specs/organization-mail.md).
    def organization_params
      params.expect(organization: [ :name, :notes, :slug, :public_form, :public_intro, *MAIL_FIELDS ]).tap do |permitted|
        %i[smtp_password imap_password].each { |name| permitted.delete(name) if permitted[name].blank? }
      end
    end
  end
end
