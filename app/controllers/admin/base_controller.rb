module Admin
  # Pages under /admin are for super administrators, and for organization
  # administrators in the parts for their own organizations
  # (specs/admin.md, specs/org-admins.md).
  class BaseController < ApplicationController
    before_action :require_admin_area

    private

    def require_admin_area
      redirect_to root_path, alert: t("flash.admin_only") unless current_user.admin_area?
    end

    # Settings of the whole service desk.
    def require_super_admin
      redirect_to org_admin_home_path, alert: t("flash.super_admin_only") unless current_user.admin?
    end

    def admin_scope
      @admin_scope ||= AdminScope.new(current_user)
    end
    helper_method :admin_scope

    # The only administered organization, or the list of them.
    def org_admin_home_path
      organizations = admin_scope.organizations.limit(2).to_a
      organizations.one? ? admin_organization_path(organizations.first) : admin_organizations_path
    end
  end
end
