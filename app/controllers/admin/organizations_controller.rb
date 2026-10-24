module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show edit update destroy]

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

    def organization_params
      params.expect(organization: %i[name notes])
    end
  end
end
