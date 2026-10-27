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

  test "assignment offers and accepts only admins and the organization's agents" do
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

  test "an agent without an organization sees only the notice; admins see everything" do
    Membership.where(user: @agent).destroy_all
    sign_in @agent
    get tickets_url
    assert_redirected_to no_organization_url

    sign_in users(:admin)
    get tickets_url(view: "all")
    numbers = css_select("td.ticket-number").map { |cell| cell.text.strip }
    assert_includes numbers, tickets(:vpn).reference
    assert_includes numbers, tickets(:printer).reference
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
