require "test_helper"

class Admin::AccessTest < ActionDispatch::IntegrationTest
  test "only administrators open the admin area" do
    [ :agent, :anna ].each do |name|
      sign_in users(name)
      [ admin_root_url, admin_users_url, new_admin_user_url, admin_organizations_url ].each do |url|
        get url
        assert_redirected_to root_url, "#{name} at #{url}"
      end
    end
  end

  test "the admin area needs sign in" do
    get admin_root_url
    assert_redirected_to new_user_session_url
  end

  test "the menu bar links to admin for administrators only" do
    sign_in users(:agent)
    get tickets_url
    assert_select ".menubar a[href=?]", admin_root_path, 0

    sign_in users(:admin)
    get admin_root_url
    assert_select ".menubar a.nav-link[href=?][aria-current=page]", admin_root_path
  end

  test "dashboard stats" do
    sign_in users(:admin)
    get admin_root_url
    assert_response :success
    assert_select ".stat", 6
    assert_select ".stat", /3\s*unsolved tickets/
  end
end
