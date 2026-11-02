require "test_helper"

# Agents work their own organizations only; admins everything
# (specs/roles.md).
class AgentScopeTest < ActionDispatch::IntegrationTest
  setup do
    @agent = User.create!(name: "Ana Acme", email: "ana.acme@example.com", password: "password-123", role: "agent")
    Membership.create!(user: @agent, organization: organizations(:acme))
  end

  test "an agent sees only their organizations' tickets, everywhere" do
    sign_in @agent
    get tickets_url(view: "all")
    numbers = css_select("td.ticket-number").map { |cell| cell.text.strip }
    assert_includes numbers, tickets(:printer).reference
    assert_not_includes numbers, tickets(:vpn).reference
    assert_select "select[name=organization] option", text: organizations(:globex).name, count: 0

    get ticket_url(tickets(:printer))
    assert_response :success
    assert_select ".message--internal"
    get ticket_url(tickets(:vpn))
    assert_response :not_found

    get board_url
    assert_select "#card_ticket_#{tickets(:vpn).id}", 0
    get tickets_url(q: tickets(:vpn).subject)
    assert_select "td.ticket-number", text: tickets(:vpn).reference, count: 0
  end

  test "assignment offers and accepts only the organization's staff" do
    sign_in @agent
    get ticket_url(tickets(:printer))
    options = css_select("select[name='ticket[assignee_id]'] option").map(&:text)
    assert_includes options, users(:admin).display_name
    assert_includes options, @agent.display_name

    globex_only = User.create!(name: "Gus Globex", email: "gus@example.com", password: "password-123", role: "agent")
    Membership.create!(user: globex_only, organization: organizations(:globex))
    get ticket_url(tickets(:printer))
    assert_not_includes css_select("select[name='ticket[assignee_id]'] option").map(&:text), globex_only.display_name

    patch assign_ticket_url(tickets(:printer)), params: { assignee_id: globex_only.id }
    assert_not_equal globex_only, tickets(:printer).reload.assignee
    assert_not tickets(:printer).apply_changes({ assignee_id: globex_only.id }, actor: @agent)

    memberships(:admin_acme).destroy
    get ticket_url(tickets(:printer))
    assert_not_includes css_select("select[name='ticket[assignee_id]'] option").map(&:text), users(:admin).display_name
  end

  test "an agent creates tickets only in their organizations" do
    sign_in @agent
    get new_ticket_url
    assert_select "select[name='ticket[organization_id]'] option", text: organizations(:globex).name, count: 0
    assert_select "select[name='ticket[requester_id]'] option", text: users(:carl).display_name, count: 0

    assert_no_difference -> { Ticket.count } do
      post tickets_url, params: { ticket: { subject: "x", description: "y", requester_id: users(:carl).id,
                                            organization_id: organizations(:globex).id } }
    end
    assert_response :unprocessable_content
    assert_difference -> { Ticket.count } do
      post tickets_url, params: { ticket: { subject: "x", description: "y", requester_id: users(:anna).id,
                                            organization_id: organizations(:acme).id } }
    end
  end

  test "an agent without an organization sees only the notice" do
    Membership.where(user: @agent).destroy_all
    sign_in @agent
    get tickets_url
    assert_redirected_to no_organization_url
  end

  # Super administrators work only their own organizations' tickets, but
  # keep the admin area for every organization (specs/roles.md).
  test "a super administrator outside an organization does not see its tickets" do
    admin = users(:admin)
    memberships(:admin_globex).destroy
    sign_in admin

    get tickets_url(view: "all")
    numbers = css_select("td.ticket-number").map { |cell| cell.text.strip }
    assert_includes numbers, tickets(:printer).reference
    assert_not_includes numbers, tickets(:vpn).reference
    get ticket_url(tickets(:vpn))
    assert_response :not_found
    get search_url(q: "VPN")
    assert_no_match "VPN disconnects", response.body
    get board_url
    assert_no_match "VPN disconnects", response.body
    assert_select "select[name=organization] option", text: organizations(:globex).name, count: 0
    assert_equal [ organizations(:acme) ], TicketReport.new(admin, {}).organizations.to_a

    assert_no_difference -> { Ticket.count } do
      post tickets_url, params: { ticket: { subject: "x", description: "y", requester_id: users(:carl).id,
                                            organization_id: organizations(:globex).id } }
    end
    assert_not tickets(:vpn).apply_changes({ assignee_id: admin.id }, actor: users(:agent))

    tickets(:vpn).update_columns(deleted_at: Time.current, deleted_by_id: users(:agent).id)
    get admin_deleted_tickets_url
    assert_select "a[href=?]", ticket_path(tickets(:vpn)), 0
    get ticket_url(tickets(:vpn))
    assert_response :not_found
    patch restore_admin_deleted_ticket_url(tickets(:vpn))
    assert_response :not_found

    # The admin area still covers the organization; the overview lists
    # only the shared tickets of the admin's organizations.
    tickets(:printer).share!(actor: users(:agent))
    tickets(:old_question).share!(actor: users(:agent))
    Ticket.where(id: tickets(:old_question).id).update_all(organization_id: organizations(:globex).id)
    get admin_organization_url(organizations(:globex))
    assert_response :success
    get admin_root_url
    assert_response :success
    assert_select "##{dom_id(tickets(:printer), :shared)}"
    assert_select "##{dom_id(tickets(:old_question), :shared)}", 0
  end

  test "a super administrator outside an organization gets no notifications of its tickets" do
    memberships(:admin_acme).destroy
    users(:admin).update!(notify_new_tickets: true)
    perform_enqueued_jobs do
      Ticket.create!(subject: "Acme only", description: "x", requester: users(:anna), organization: organizations(:acme),
                     actor: users(:anna))
    end
    assert_not Notification.exists?(user: users(:admin))
    assert_not ActionMailer::Base.deliveries.any? { |mail| mail.to == [ users(:admin).email ] }
  end

  test "agents outside the organization get no notifications of its tickets" do
    globex_only = User.create!(name: "Gus Globex", email: "gus@example.com", password: "password-123", role: "agent",
                               notify_new_tickets: true)
    Membership.create!(user: globex_only, organization: organizations(:globex))
    perform_enqueued_jobs do
      Ticket.create!(subject: "Acme only", description: "x", requester: users(:anna), organization: organizations(:acme),
                     actor: users(:anna))
    end
    assert_not Notification.exists?(user: globex_only)
    assert_not ActionMailer::Base.deliveries.any? { |mail| mail.to == [ globex_only.email ] }
  end
end
