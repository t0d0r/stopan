module Admin
  # Adds users to organizations and removes them; a removed requester loses
  # access to that organization's tickets at once (specs/roles.md). The
  # member picker sends several users at once (specs/admin.md "Adding
  # members").
  class MembershipsController < BaseController
    def create
      organization = Organization.find(params[:organization_id])
      users = User.where(id: user_ids).to_a
      return redirect_to(admin_organization_path(organization), alert: t("flash.members_none_chosen")) if users.empty?

      users.each { |user| organization.memberships.find_or_create_by!(user: user) }
      notice = users.one? ? t("flash.member_added", name: users.first.display_name) : t("flash.members_added", count: users.size)
      redirect_to admin_organization_path(organization), notice: notice
    end

    def destroy
      membership = Membership.find(params[:id])
      membership.destroy!
      redirect_to admin_organization_path(membership.organization),
                  notice: t("flash.member_removed", name: membership.user.display_name)
    end

    private

    # user_ids[] from the picker, or one membership[user_id].
    def user_ids
      ids = Array(params[:user_ids]).compact_blank
      ids << params.dig(:membership, :user_id) if params.dig(:membership, :user_id).present?
      ids.map(&:to_s).uniq.first(500)
    end
  end
end
