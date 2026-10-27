# The only page a requester without an organization sees (specs/roles.md).
class NoOrganizationsController < ApplicationController
  skip_before_action :require_organization

  def show
    redirect_to root_path unless without_organization?
  end
end
