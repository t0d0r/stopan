require "test_helper"

# An agent who administers Acme but works Globex as a plain agent
# (specs/org-admins.md).
class Admin::OrgAdminsTest < ActionDispatch::IntegrationTest
  setup do
    memberships(:agent_acme).update!(admin: true)
    @acme = organizations(:acme)
    @globex = organizations(:globex)
    sign_in users(:agent)
  end

  test "the account menu links to the admin area, which starts at the organization" do
    get tickets_url
    assert_select ".account-menu .account-menu__item[href=?]", admin_root_path
    get admin_root_url
    assert_redirected_to admin_organization_url(@acme)

    memberships(:agent_globex).update!(admin: true)
    get admin_root_url
    assert_redirected_to admin_organizations_url
  end

  test "super administrator pages redirect" do
    [ admin_settings_url, admin_google_setup_url, new_admin_organization_url ].each do |url|
      get url
      assert_redirected_to admin_organization_url(@acme), url
      assert_equal "Only super administrators can open that page.", flash[:alert]
    end
    patch admin_settings_url, params: { app_setting: { auto_postpone_days: 3 } }
    assert_redirected_to admin_organization_url(@acme)
    post admin_stages_url, params: { stage: { status: "open", name: "X" } }
    assert_redirected_to admin_organization_url(@acme)
    assert_no_difference -> { Impersonation.count } do
      post admin_user_impersonation_url(users(:anna))
    end
    assert_no_difference -> { Organization.count } do
      post admin_organizations_url, params: { organization: { name: "New" } }
      delete admin_organization_url(@acme)
    end
  end

  test "own organization only: list, page, edit, update, flush" do
    get admin_organizations_url
    assert_response :success
    assert_select "a[href=?]", admin_organization_path(@acme)
    assert_select "a[href=?]", admin_organization_path(@globex), 0
    assert_select "a[href=?]", new_admin_organization_path, 0
    assert_select ".admin-tabs a[href=?]", admin_settings_path, 0
    assert_select ".admin-tabs a[href=?]", admin_root_path, 0

    get admin_organization_url(@acme)
    assert_response :success
    get edit_admin_organization_url(@acme)
    assert_response :success
    patch admin_organization_url(@acme), params: { organization: { notes: "Four shops." } }
    assert_equal "Four shops.", @acme.reload.notes

    [ -> { get admin_organization_url(@globex) }, -> { get edit_admin_organization_url(@globex) },
      -> { patch admin_organization_url(@globex), params: { organization: { notes: "x" } } },
      -> { post flush_admin_organization_url(@globex), params: { confirm_name: @globex.name } },
      -> { post mail_test_admin_organization_url(@globex) },
      -> { get admin_organization_google_connect_url(@globex) },
      -> { delete admin_organization_mail_oauth_url(@globex) } ].each do |request|
      request.call
      assert_response :not_found
    end
    assert_not_equal "x", @globex.reload.notes

    assert_difference -> { @acme.tickets.count }, -@acme.tickets.count do
      post flush_admin_organization_url(@acme), params: { confirm_name: @acme.name }
    end
  end

  test "members: only allowed users are added, own and marked memberships stay" do
    get admin_organization_url(@acme)
    assert_select "[data-member-picker] input[value=?]", users(:drifter).id.to_s
    assert_select "[data-member-picker] input[value=?]", users(:admin).id.to_s, 0
    assert_select "[data-member-picker] input[value=?]", users(:carl).id.to_s, 0
    assert_select "form[action=?]", admin_membership_path(memberships(:agent_acme)), 0
    assert_select "form[action=?]", admin_membership_path(memberships(:boris_acme))
    assert_select "form[action=?] input[name='membership[admin]']", admin_membership_path(memberships(:anna_acme)), 0

    assert_no_difference -> { Membership.count } do
      post admin_organization_memberships_url(@acme), params: { user_ids: [ users(:carl).id, users(:admin).id ] }
    end
    assert_difference -> { @acme.memberships.count }, 1 do
      post admin_organization_memberships_url(@acme), params: { user_ids: [ users(:drifter).id ] }
    end
    assert_no_difference -> { Membership.count } do
      post admin_organization_memberships_url(@globex), params: { user_ids: [ users(:drifter).id ] }
    end
    assert_response :not_found

    assert_no_difference -> { Membership.count } do
      delete admin_membership_url(memberships(:agent_acme))
    end
    assert_equal "Only a super administrator can remove this member.", flash[:alert]
    memberships(:agent_two_acme).update!(admin: true)
    assert_no_difference -> { Membership.count } do
      delete admin_membership_url(memberships(:agent_two_acme))
    end
    admin_acme = Membership.create!(user: users(:admin), organization: @acme)
    assert_no_difference -> { Membership.count } do
      delete admin_membership_url(admin_acme)
    end
    assert_difference -> { Membership.count }, -1 do
      delete admin_membership_url(memberships(:boris_acme))
    end
    delete admin_membership_url(memberships(:carl_globex))
    assert_response :not_found
  end

  test "only super administrators set the mark" do
    patch admin_membership_url(memberships(:agent_two_acme)), params: { membership: { admin: "1" } }
    assert_not memberships(:agent_two_acme).reload.admin?

    sign_in users(:admin)
    get admin_organization_url(@acme)
    assert_select "form[action=?] input[name='membership[admin]'][value='1']", admin_membership_path(memberships(:agent_two_acme))
    assert_select "form[action=?] button.icon-action--org-admin[aria-pressed=true]", admin_membership_path(memberships(:agent_acme))
    assert_select "form[action=?] input[name='membership[admin]']", admin_membership_path(memberships(:anna_acme)), 0
    assert_select ".role-pill--org-admin", "Organization admin"
    patch admin_membership_url(memberships(:agent_two_acme)), params: { membership: { admin: "1" } }
    assert memberships(:agent_two_acme).reload.admin?
    patch admin_membership_url(memberships(:anna_acme)), params: { membership: { admin: "1" } }
    assert_not memberships(:anna_acme).reload.admin?
  end

  test "users: members of the organization, edited only when managed" do
    get admin_users_url
    assert_response :success
    assert_select "##{dom_id(users(:anna))}"
    assert_select "##{dom_id(users(:agent_two))}"
    assert_select "##{dom_id(users(:carl))}", 0
    assert_select "##{dom_id(users(:admin))}", 0
    assert_select "##{dom_id(users(:drifter))}", 0
    assert_select "a[href=?]", edit_admin_user_path(users(:anna))
    assert_select "a[href=?]", edit_admin_user_path(users(:agent_two)), 0
    assert_select "a[href=?]", edit_admin_user_path(users(:agent)), 0
    assert_select "select#role option[value=admin]", 0
    assert_select "##{dom_id(users(:agent_two))} td", text: /Globex/, count: 0

    get edit_admin_user_url(users(:anna))
    assert_response :success
    assert_select "select#user_role option[value=admin]", 0
    assert_select "input[name='user[organization_ids][]'][value=?]", @globex.id.to_s, 0
    assert_select ".impersonation-panel", 0

    [ users(:agent_two), users(:carl), users(:admin), users(:agent) ].each do |user|
      get edit_admin_user_url(user)
      assert_response :not_found, user.email
      patch admin_user_url(user), params: { user: { name: "Changed" } }
      assert_response :not_found, user.email
    end
    delete admin_user_url(users(:drifter))
    assert_response :not_found
  end

  test "users: roles up to agent, in own organizations" do
    patch admin_user_url(users(:anna)), params: { user: { role: "admin", organization_ids: [ @acme.id ] } }
    assert_response :unprocessable_content
    assert_equal "requester", users(:anna).reload.role

    patch admin_user_url(users(:anna)), params: { user: { name: "Anna B", organization_ids: [ @acme.id, @globex.id ] } }
    assert_redirected_to admin_users_url
    assert_equal [ @acme ], users(:anna).reload.organizations.to_a

    patch admin_user_url(users(:anna)), params: { user: { organization_ids: [ "" ] } }
    assert_response :unprocessable_content
    assert_equal [ @acme ], users(:anna).reload.organizations.to_a

    assert_no_difference -> { User.count } do
      post admin_users_url, params: { user: { email: "new@example.com", password: "secret-pass-123", password_confirmation: "secret-pass-123",
                                              role: "requester", organization_ids: [ @globex.id ] } }
    end
    assert_response :unprocessable_content
    assert_difference -> { @acme.memberships.count }, 1 do
      post admin_users_url, params: { user: { email: "new@example.com", password: "secret-pass-123", password_confirmation: "secret-pass-123",
                                              role: "agent", organization_ids: [ @acme.id ] } }
    end
  end

  test "messages only to the organization's members" do
    get new_admin_message_url
    assert_select "option[value=all]", 0
    assert_select "option[value='role:agent']", 0
    assert_select "option[value=?]", "organization:#{@acme.id}"
    assert_select "option[value=?]", "organization:#{@globex.id}", 0
    assert_select "option[value=?]", "user:#{users(:anna).id}"
    assert_select "option[value=?]", "user:#{users(:carl).id}", 0

    [ "all", "role:requester", "organization:#{@globex.id}", "user:#{users(:carl).id}" ].each do |recipients|
      assert_no_difference -> { Notification.count }, recipients do
        post admin_messages_url, params: { admin_message: { recipients: recipients, text: "Hello" } }
      end
    end
    assert_difference -> { Notification.count }, 1 do
      post admin_messages_url, params: { admin_message: { recipients: "user:#{users(:anna).id}", text: "Hello" } }
    end
  end

  test "deleted tickets of the own organization only" do
    printer = tickets(:printer)
    vpn = tickets(:vpn)
    [ printer, vpn ].each { |ticket| ticket.update_columns(deleted_at: Time.current, deleted_by_id: users(:admin).id) }

    get admin_deleted_tickets_url
    assert_response :success
    assert_select "a[href=?]", ticket_path(printer)
    assert_select "a[href=?]", ticket_path(vpn), 0

    get ticket_url(printer)
    assert_response :success
    get ticket_url(vpn)
    assert_response :not_found

    patch restore_admin_deleted_ticket_url(vpn)
    assert_response :not_found
    patch restore_admin_deleted_ticket_url(printer)
    assert_nil printer.reload.deleted_at
  end

  test "a plain agent still has no admin area" do
    memberships(:agent_acme).update!(admin: false)
    get admin_organization_url(@acme)
    assert_redirected_to root_url
  end
end
