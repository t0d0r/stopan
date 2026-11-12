module Api
  module V1
    # Adding users to organizations and removing them, for administrators
    # (specs/roles.md).
    class MembershipsController < BaseController
      before_action :require_admin!

      # One membership[user_id], or several user_ids[] at once (specs/admin.md "Adding members").
      def create
        organization = Organization.find(params[:organization_id])
        if params[:user_ids].present?
          users = User.where(id: Array(params[:user_ids]).first(500)).to_a
          memberships = users.map { |user| organization.memberships.find_or_create_by!(user: user) }
          return render json: { memberships: memberships.map { |membership| { id: membership.id, admin: membership.admin?, user: user_json(membership.user) } } },
                        status: :created
        end

        user = User.find(params.expect(membership: [ :user_id ])[:user_id])
        membership = organization.memberships.find_or_create_by!(user: user)
        render json: { membership: membership_json(membership) }, status: :created
      end

      # The organization administrator mark, for agents only
      # (specs/org-admins.md).
      def update
        membership = Membership.find(params[:id])
        return render_invalid(membership) unless membership.update(admin: flag(params.expect(membership: [ :admin ])[:admin]))

        render json: { membership: membership_json(membership) }
      end

      def destroy
        Membership.find(params[:id]).destroy!
        head :no_content
      end

      private

      def membership_json(membership)
        { id: membership.id, admin: membership.admin?, organization: organization_json(membership.organization),
          user: user_json(membership.user) }
      end
    end
  end
end
