module Api
  module V1
    # Users, for administrators (specs/admin.md), with the rules of
    # Admin::UsersController: a blank password keeps the current one, no
    # change of one's own role or deactivation, no deleting a user with
    # ticket history or oneself.
    class UsersController < BaseController
      before_action :require_admin!
      before_action :set_user, only: %i[show update destroy]

      def index
        users = User.includes(:organizations).ordered
        users = users.where(role: params[:role]) if params[:role].in?(User::ROLES)
        users = users.search(params[:q].to_s.squish.first(100)) if params[:q].present?
        render json: { users: users.map { |user| admin_user_json(user) } }
      end

      def show
        render json: { user: admin_user_json(@user) }
      end

      def create
        user = User.new(user_params.except(:deactivated))
        return render_invalid(user) unless user.save

        render json: { user: admin_user_json(user) }, status: :created
      end

      def update
        attributes = user_params
        attributes = attributes.except(:password, :password_confirmation) if attributes[:password].blank?
        attributes = attributes.except(:role, :deactivated) if @user == current_user
        deactivated = attributes.delete(:deactivated)
        @user.deactivated_at = flag(deactivated) ? (@user.deactivated_at || Time.current) : nil unless deactivated.nil?
        saved = false
        User.transaction do
          @user.assign_attributes(attributes)
          saved = @user.save
          raise ActiveRecord::Rollback unless saved

          @user.release_assigned_tickets!(current_user) if !@user.staff? || @user.deactivated?
        end
        return render_invalid(@user) unless saved

        render json: { user: admin_user_json(@user.reload) }
      end

      def destroy
        if @user == current_user
          render_error(:forbidden, :forbidden, message: I18n.t("flash.user_self_delete"))
        elsif @user.ticket_history?
          render_error(:invalid, :unprocessable_content, message: I18n.t("flash.user_has_history", name: @user.display_name))
        else
          @user.destroy!
          head :no_content
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

      def admin_user_json(user)
        user_json(user).merge(username: user.username, deactivated: user.deactivated?, language: user.language,
                              created_at: time_json(user.created_at), last_sign_in_at: time_json(user.last_sign_in_at),
                              organizations: user.organizations.map { |organization| organization_json(organization) })
      end
    end
  end
end
