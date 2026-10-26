require "test_helper"

class Admin::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "lists organizations with counts" do
    get admin_organizations_url
    assert_response :success
    assert_select ".table-organizations tbody tr", 2
    assert_select "#organization_#{organizations(:acme).id} td.num", text: "2", minimum: 1
  end

  test "the organization search has no button" do
    get admin_organizations_url
    assert_select "form.filters[data-filter-form] input[type=search][name=q]"
    assert_select "form.filters input[type=submit]", 0
  end

  test "creates, shows and updates an organization" do
    assert_difference("Organization.count") do
      post admin_organizations_url, params: { organization: { name: "  Initech  ", notes: "Printers everywhere." } }
    end
    org = Organization.find_by!(name: "Initech")
    assert_redirected_to admin_organization_url(org)
    follow_redirect!
    assert_select "h1", "Initech"

    patch admin_organization_url(org), params: { organization: { name: "Initech Ltd" } }
    assert_equal "Initech Ltd", org.reload.name
  end

  test "names are unique ignoring case" do
    post admin_organizations_url, params: { organization: { name: "acme bakery" } }
    assert_response :unprocessable_content
  end

  test "an organization with tickets cannot be deleted" do
    assert_no_difference("Organization.count") { delete admin_organization_url(organizations(:acme)) }
    org = Organization.create!(name: "Empty Co")
    org.users << users(:drifter)
    assert_difference([ "Organization.count", "Membership.count" ], -1) { delete admin_organization_url(org) }
  end

  test "adds and removes members" do
    org = organizations(:globex)
    assert_difference("Membership.count") do
      post admin_organization_memberships_url(org), params: { membership: { user_id: users(:drifter).id } }
    end
    assert users(:drifter).member_of?(org)

    delete admin_membership_url(memberships(:carl_globex))
    assert_redirected_to admin_organization_url(org)
    assert_empty Ticket.visible_to(users(:carl).reload)
  end

  test "agents cannot manage memberships" do
    sign_in users(:agent)
    assert_no_difference("Membership.count") do
      post admin_organization_memberships_url(organizations(:globex)), params: { membership: { user_id: users(:drifter).id } }
    end
    assert_redirected_to root_url
  end
end
