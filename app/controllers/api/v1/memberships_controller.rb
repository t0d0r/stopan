module Api
  module V1
    # Adding users to organizations and removing them, for administrators
    # (specs/roles.md).
    class MembershipsController < BaseController
      before_action :require_admin!

      def create
        organization = Organization.find(params[:organization_id])
        user = User.find(params.expect(membership: [ :user_id ])[:user_id])
        membership = organization.memberships.find_or_create_by!(user: user)
        render json: { membership: { id: membership.id, organization: organization_json(organization), user: user_json(user) } },
               status: :created
      end

      def destroy
        Membership.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
