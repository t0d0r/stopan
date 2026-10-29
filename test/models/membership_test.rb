require "test_helper"

# The organization admin mark (specs/org-admins.md).
class MembershipTest < ActiveSupport::TestCase
  test "only agents carry the organization admin mark" do
    assert memberships(:agent_acme).update(admin: true)
    assert_not memberships(:anna_acme).update(admin: true)
    assert_includes memberships(:anna_acme).errors[:admin], "can only be set for agents"

    admin_membership = Membership.new(user: users(:admin), organization: organizations(:acme), admin: true)
    assert_not admin_membership.valid?
  end

  test "a role change away from agent clears every mark" do
    memberships(:agent_acme).update!(admin: true)
    memberships(:agent_globex).update!(admin: true)
    users(:agent).update!(role: "requester")
    assert_not memberships(:agent_acme).reload.admin?
    assert_not memberships(:agent_globex).reload.admin?
  end

  test "administered organizations per role" do
    memberships(:agent_acme).update!(admin: true)
    agent = users(:agent)
    assert_equal [ organizations(:acme) ], agent.administered_organizations.to_a
    assert agent.administers?(organizations(:acme))
    assert_not agent.administers?(organizations(:globex))
    assert agent.org_admin?
    assert agent.admin_area?

    assert_equal Organization.count, users(:admin).administered_organizations.count
    assert users(:admin).administers?(organizations(:globex))
    assert_not users(:admin).org_admin?
    assert users(:admin).admin_area?

    assert_empty users(:agent_two).administered_organizations
    assert_not users(:agent_two).admin_area?
    assert_empty users(:anna).administered_organizations
    assert_not users(:anna).administers?(organizations(:acme))
  end
end
