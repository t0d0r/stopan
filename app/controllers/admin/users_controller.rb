module Admin
  # Organization administrators list the members of their organizations
  # and edit only the users they manage, up to agent (specs/org-admins.md).
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy]

    def index
      @role = params[:role].presence_in(admin_scope.roles)
      @query = params[:q].to_s.squish.first(100).presence
      users = admin_scope.users.includes(:organizations).ordered
      users = users.where(role: @role) if @role
      users = users.search(@query) if @query
      @users = users.to_a
      # Organization administrators see only their organizations' names.
      @shown_organization_ids = admin_scope.organizations.pluck(:id).to_set unless current_user.admin?
      @manageable_ids = admin_scope.manageable_users.where(id: @users.map(&:id)).pluck(:id).to_set
      @deletable_ids = @manageable_ids - User.ids_with_ticket_history(@users.map(&:id)) - [ current_user.id ]
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params.except(:deactivated))
      if acceptable? && @user.save
        redirect_to admin_users_path, notice: t("flash.user_created", name: @user.display_name)
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    # A blank password keeps the current one. Admins cannot change their own
    # role or deactivate themselves, so there is always an admin.
    def update
      attributes = user_params
      attributes = attributes.except(:password, :password_confirmation) if attributes[:password].blank?
      attributes = attributes.except(:role, :deactivated) if @user == current_user
      deactivated = attributes.delete(:deactivated)
      @user.deactivated_at = deactivated == "1" ? (@user.deactivated_at || Time.current) : nil unless deactivated.nil?
      # Membership ids are written on assignment, so everything happens in one
      # transaction that is rolled back when the user is invalid.
      saved = false
      User.transaction do
        @user.assign_attributes(attributes)
        saved = acceptable? && @user.save
        raise ActiveRecord::Rollback unless saved

        release_tickets_if_needed
      end
      if saved
        # Devise signs a user out when their password hash changes.
        bypass_sign_in(@user) if @user == current_user
        redirect_to admin_users_path, notice: t("flash.user_updated", name: @user.display_name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: t("flash.user_self_delete")
      elsif @user.ticket_history?
        redirect_to admin_users_path, alert: t("flash.user_has_history", name: @user.display_name)
      else
        @user.destroy!
        redirect_to admin_users_path, notice: t("flash.user_deleted", name: @user.display_name)
      end
    end

    private

    def set_user
      @user = admin_scope.manageable_users.find(params[:id])
    end

    def user_params
      params.expect(user: [ :name, :nickname, :username, :email, :password, :password_confirmation, :role, :deactivated,
                            organization_ids: [] ]).tap do |permitted|
        if permitted.key?(:organization_ids) && !current_user.admin?
          permitted[:organization_ids] = admin_scope.organizations.where(id: permitted[:organization_ids]).pluck(:id)
        end
      end
    end

    # Roles up to agent, and at least one of their own organizations, for
    # organization administrators; other organizations in the request are
    # dropped before this (user_params).
    def acceptable?
      @user.valid?
      @user.errors.add(:role, :inclusion) unless @user.role.in?(admin_scope.roles)
      if !current_user.admin? && @user.organization_ids.empty?
        @user.errors.add(:organization_ids, :choose_own)
      end
      @user.errors.none?
    end

    # A user who is no longer active staff keeps no unsolved tickets
    # (specs/admin.md).
    def release_tickets_if_needed
      @user.release_assigned_tickets!(current_user) if !@user.staff? || @user.deactivated?
    end
  end
end
