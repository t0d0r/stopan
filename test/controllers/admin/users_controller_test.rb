require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "lists users with roles and filters" do
    get admin_users_url
    assert_response :success
    assert_select ".table-users tbody tr", User.count
    assert_select "#user_#{users(:retired).id} .state-tag", "Deactivated"

    get admin_users_url(role: "agent")
    assert_select ".table-users tbody tr", 3
    get admin_users_url(q: "ANNA")
    assert_select ".table-users tbody tr", 1
  end

  test "creates an agent with memberships" do
    assert_difference("User.count") do
      post admin_users_url, params: { user: { name: "Nina New", email: "nina@example.com", password: "s3cret-pass",
                                              password_confirmation: "s3cret-pass", role: "agent",
                                              organization_ids: [ "", organizations(:acme).id ] } }
    end
    assert_redirected_to admin_users_url
    nina = User.find_by!(email: "nina@example.com")
    assert nina.agent?
    assert_equal [ organizations(:acme) ], nina.organizations.to_a
  end

  test "rejects a duplicate username and a bad role" do
    assert_no_difference("User.count") do
      post admin_users_url, params: { user: { username: "ANNA", email: "a2@example.com", password: "s3cret-pass",
                                              password_confirmation: "s3cret-pass", role: "requester" } }
    end
    assert_response :unprocessable_content
    post admin_users_url, params: { user: { email: "a3@example.com", password: "s3cret-pass",
                                            password_confirmation: "s3cret-pass", role: "overlord" } }
    assert_response :unprocessable_content
  end

  test "updates a user and keeps the password when it is blank" do
    boris = users(:boris)
    patch admin_user_url(boris), params: { user: { email: "boris2@example.com", password: "", password_confirmation: "",
                                                   organization_ids: [ "", organizations(:globex).id ] } }
    assert_redirected_to admin_users_url
    boris.reload
    assert_equal "boris2@example.com", boris.email
    assert boris.valid_password?("password")
    assert_equal [ organizations(:globex) ], boris.organizations.to_a
  end

  test "an invalid update leaves memberships alone" do
    boris = users(:boris)
    patch admin_user_url(boris), params: { user: { email: "", organization_ids: [ "" ] } }
    assert_response :unprocessable_content
    assert_equal [ organizations(:acme) ], boris.reload.organizations.to_a
  end

  test "demoting an agent unassigns their unsolved tickets" do
    patch admin_user_url(users(:agent)), params: { user: { role: "requester" } }
    assert users(:agent).reload.requester?
    assert_nil tickets(:printer).reload.assignee
    assert_equal users(:admin), tickets(:printer).events.last.actor
  end

  test "deactivating a user ends sign-in and unassigns tickets" do
    patch admin_user_url(users(:agent_two)), params: { user: { deactivated: "1" } }
    assert users(:agent_two).reload.deactivated?
    assert_nil tickets(:vpn).reload.assignee

    patch admin_user_url(users(:agent_two)), params: { user: { deactivated: "0" } }
    assert_not users(:agent_two).reload.deactivated?
  end

  test "an administrator cannot change their own role, deactivate or delete themselves" do
    admin = users(:admin)
    patch admin_user_url(admin), params: { user: { role: "requester", deactivated: "1" } }
    admin.reload
    assert admin.admin?
    assert_not admin.deactivated?

    assert_no_difference("User.count") { delete admin_user_url(admin) }
    assert_redirected_to admin_users_url
  end

  test "an administrator stays signed in after changing their own password" do
    patch admin_user_url(users(:admin)), params: { user: { password: "new-pass-123", password_confirmation: "new-pass-123" } }
    get admin_root_url
    assert_response :success
  end

  test "deletes users without history and refuses users with history" do
    assert_difference("User.count", -1) { delete admin_user_url(users(:drifter)) }
    assert_no_difference("User.count") { delete admin_user_url(users(:anna)) }
    follow_redirect!
    assert_select ".flash", /has ticket history/
  end
end
