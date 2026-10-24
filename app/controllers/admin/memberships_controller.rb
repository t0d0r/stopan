module Admin
  # Adds users to organizations and removes them; a removed requester loses
  # access to that organization's tickets at once (specs/roles.md).
  class MembershipsController < BaseController
    def create
      organization = Organization.find(params[:organization_id])
      user = User.find(params.expect(membership: [ :user_id ])[:user_id])
      membership = organization.memberships.find_or_create_by!(user: user)
      redirect_to admin_organization_path(organization), notice: t("flash.member_added", name: membership.user.display_name)
    end

    def destroy
      membership = Membership.find(params[:id])
      membership.destroy!
      redirect_to admin_organization_path(membership.organization),
                  notice: t("flash.member_removed", name: membership.user.display_name)
    end
  end
end
