module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy]

    def index
      @role = params[:role].presence_in(User::ROLES)
      @query = params[:q].to_s.squish.first(100).presence
      users = User.includes(:organizations).ordered
      users = users.where(role: @role) if @role
      users = users.search(@query) if @query
      @users = users
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params.except(:deactivated))
      if @user.save
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
        saved = @user.save
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
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :name, :username, :email, :password, :password_confirmation, :role, :deactivated,
                            organization_ids: [] ])
    end

    # A user who is no longer active staff keeps no unsolved tickets
    # (specs/admin.md).
    def release_tickets_if_needed
      @user.release_assigned_tickets!(current_user) if !@user.staff? || @user.deactivated?
    end
  end
end
