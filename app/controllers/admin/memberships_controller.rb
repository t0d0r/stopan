module Admin
  # Adds users to organizations and removes them; a removed requester loses
  # access to that organization's tickets at once (specs/roles.md). The
  # member picker sends several users at once (specs/admin.md "Adding
  # members"). Organization administrators work only in their
  # organizations, and only super administrators set the organization
  # admin mark (specs/org-admins.md).
  class MembershipsController < BaseController
    before_action :require_super_admin, only: :update
    before_action :set_membership, only: %i[update destroy]

    def create
      organization = admin_scope.organizations.find(params[:organization_id])
      users = admin_scope.addable_users.where(id: user_ids).to_a
      return redirect_to(admin_organization_path(organization), alert: t("flash.members_none_chosen")) if users.empty?

      users.each { |user| organization.memberships.find_or_create_by!(user: user) }
      notice = users.one? ? t("flash.member_added", name: users.first.display_name) : t("flash.members_added", count: users.size)
      redirect_to admin_organization_path(organization), notice: notice
    end

    # The organization admin mark, for agents only.
    def update
      admin = params.dig(:membership, :admin).to_s == "1"
      if @membership.update(admin: admin)
        key = admin ? "flash.org_admin_granted" : "flash.org_admin_removed"
        redirect_to admin_organization_path(@membership.organization),
                    notice: t(key, name: @membership.user.display_name, organization: @membership.organization.name)
      else
        redirect_to admin_organization_path(@membership.organization), alert: @membership.errors.full_messages.to_sentence
      end
    end

    def destroy
      unless admin_scope.removable?(@membership)
        return redirect_to admin_organization_path(@membership.organization), alert: t("flash.member_not_removable")
      end

      @membership.destroy!
      redirect_to admin_organization_path(@membership.organization),
                  notice: t("flash.member_removed", name: @membership.user.display_name)
    end

    private

    def set_membership
      @membership = Membership.where(organization_id: admin_scope.organizations.select(:id)).find(params[:id])
    end

    # user_ids[] from the picker, or one membership[user_id].
    def user_ids
      ids = Array(params[:user_ids]).compact_blank
      ids << params.dig(:membership, :user_id) if params.dig(:membership, :user_id).present?
      ids.map(&:to_s).uniq.first(500)
    end
  end
end
