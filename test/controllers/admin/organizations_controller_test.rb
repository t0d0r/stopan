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

  test "the email language is one of the app's languages or blank" do
    org = organizations(:acme)
    get edit_admin_organization_url(org)
    assert_select "select[name='organization[mail_locale]'] option[value='']"
    assert_select "select[name='organization[mail_locale]'] option[value=de]"

    patch admin_organization_url(org), params: { organization: { mail_locale: "de" } }
    assert_equal "de", org.reload.mail_locale
    patch admin_organization_url(org), params: { organization: { mail_locale: "xx" } }
    assert_response :unprocessable_content
    assert_equal "de", org.reload.mail_locale
    patch admin_organization_url(org), params: { organization: { mail_locale: "" } }
    assert_nil org.reload.mail_locale
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

  test "the member picker lists non-members with check boxes and adds several at once (specs/admin.md)" do
    org = organizations(:globex)
    get admin_organization_url(org)
    assert_select "form[data-member-picker][action=?]", admin_organization_memberships_path(org) do
      assert_select "[data-picker-search-wrap][hidden] input[type=search][data-picker-search]:not([name])"
      assert_select "li[data-picker-row] input[type=checkbox][name='user_ids[]'][value=?]", users(:drifter).id.to_s
      assert_select "li[data-picker-row] input[value=?]", users(:carl).id.to_s, count: 0
      assert_select "li[data-picker-row][data-search*=?]", users(:drifter).email.downcase
    end
    assert_select "select[name='membership[user_id]']", 0

    newcomer = User.create!(name: "New Comer", email: "new@example.com", password: "s3cret-pass-1", role: "requester")
    assert_difference("Membership.count", 2) do
      post admin_organization_memberships_url(org), params: { user_ids: [ users(:drifter).id, newcomer.id ] }
    end
    assert_equal "2 members added.", flash[:notice]
    post admin_organization_memberships_url(org), params: { user_ids: [ "" ] }
    assert_equal "Tick at least one user first.", flash[:alert]
  end

  test "agents cannot manage memberships" do
    sign_in users(:agent)
    assert_no_difference("Membership.count") do
      post admin_organization_memberships_url(organizations(:globex)), params: { membership: { user_id: users(:drifter).id } }
    end
    assert_redirected_to root_url
  end

  test "mail settings: passwords are write-only, the test email goes through the organization" do
    org = organizations(:acme)
    settings = { smtp_enabled: "1", smtp_address: "smtp.acme.example", smtp_port: "587", smtp_security: "starttls",
                 smtp_username: "desk", smtp_password: "s3cret-pass", mail_from: "Acme <support@acme.example>" }
    patch admin_organization_url(org), params: { organization: settings }
    assert_equal "s3cret-pass", org.reload.smtp_password

    get edit_admin_organization_url(org)
    assert_select "input[type=password][name='organization[smtp_password]']:not([value])"
    assert_not_includes response.body, "s3cret-pass"
    assert_select "input[type=checkbox][name='organization[remove_smtp_password]']"

    patch admin_organization_url(org), params: { organization: settings.merge(smtp_password: "") }
    assert_equal "s3cret-pass", org.reload.smtp_password

    get admin_organization_url(org)
    assert_select "form[action=?]", mail_test_admin_organization_path(org)
    assert_not_includes response.body, "s3cret-pass"

    post mail_test_admin_organization_url(org)
    assert_redirected_to admin_organization_url(org)
    assert_equal "A test email was sent to #{users(:admin).email}.", flash[:notice]
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ users(:admin).email ], mail.to
    assert_equal "smtp.acme.example", mail.delivery_method.settings[:address]
  end

  test "the test email needs SMTP turned on" do
    post mail_test_admin_organization_url(organizations(:globex))
    assert_equal "Turn on this organization's SMTP first.", flash[:alert]
  end

  test "the mailbox check needs the mailbox on; the button shows when it is" do
    post mailbox_check_admin_organization_url(organizations(:globex))
    assert_equal "Turn on this organization's mailbox first.", flash[:alert]

    organizations(:acme).update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                                 mailbox_address: "support@acme.example")
    get admin_organization_url(organizations(:acme))
    assert_select "form[action=?] button", mailbox_check_admin_organization_path(organizations(:acme)), "Check the mailbox"
  end

  test "the public page link is easy to copy from the list, the page and the edit form" do
    org = organizations(:acme)
    org.update!(public_form: true)
    url = public_request_url(org.slug)

    get admin_organizations_url
    assert_select "#organization_#{org.id} button.icon-action[data-copy-value=?]", url
    assert_select "#organization_#{organizations(:globex).id} button[data-copy-value]", 0

    get admin_organization_url(org)
    assert_select "input#public-form-url[readonly][value=?]", url
    assert_select "button[data-copy=public-form-url]"
    assert_select "a[href=?][target=_blank]", url

    get edit_admin_organization_url(org)
    assert_select "#public-form-settings input#public-form-url-edit[value=?]", url
    assert_select "#public-form-settings button[data-copy=public-form-url-edit]"

    org.update!(public_form: false)
    get edit_admin_organization_url(org)
    assert_select "#public-form-settings .field-hint", /The page is off/
  end
end
