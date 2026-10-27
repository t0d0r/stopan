require "test_helper"

# End-to-end flows through the real pages, as a requester and an agent
# would click through them (specs/roles.md, specs/timeline.md).
class ServiceDeskFlowTest < ActionDispatch::IntegrationTest
  test "a ticket from creation to closing" do
    # The requester opens a ticket.
    sign_in users(:boris)
    get new_ticket_url
    assert_select "form.stack-form"
    post tickets_url, params: { ticket: { subject: "Card terminal offline", description: "The terminal shows error 42." } }
    ticket = Ticket.order(:number).last
    follow_redirect!
    assert_select "h1.ticket-note__title", /#\d+\s+Card terminal offline/
    assert_select ".ticket-head .pill--status", "New"

    # An agent finds it in the unassigned view, takes it and leaves a note.
    sign_in users(:agent)
    get tickets_url(view: "unassigned")
    assert_select "a.ticket-link", text: "Card terminal offline"
    patch ticket_url(ticket), params: { ticket: { status: "new", priority: "high", assignee_id: users(:agent).id } }
    post ticket_comments_url(ticket), params: { comment: { body: "INTERNAL: terminal firmware is outdated", internal: "1" } }
    post ticket_comments_url(ticket), params: { comment: { body: "Please restart the terminal and send a photo.",
                                                           internal: "0", status: "pending" } }
    assert_equal "pending", ticket.reload.status
    get tickets_url(view: "mine")
    assert_select "a.ticket-link", text: "Card terminal offline" # pending is unsolved, so still mine
    get tickets_url(view: "pending")
    assert_select "a.ticket-link", text: "Card terminal offline"

    # The requester sees the public reply but not the note, and answers.
    sign_in users(:boris)
    get ticket_url(ticket)
    assert_match "Please restart the terminal", response.body
    assert_no_match "INTERNAL", response.body
    assert_no_match "changed the priority", response.body
    assert_select ".timeline__item", text: /changed the status from New to Pending/
    post ticket_comments_url(ticket), params: { comment: { body: "Restarted, photo attached.", files: [ upload ] } }
    assert_equal "open", ticket.reload.status

    # The agent resolves and later closes it.
    sign_in users(:agent)
    post ticket_comments_url(ticket), params: { comment: { body: "Firmware updated remotely.", internal: "0", status: "resolved" } }
    patch ticket_url(ticket), params: { ticket: { status: "closed" } }
    assert_equal "closed", ticket.reload.status

    # Closed: the requester can no longer reply and is told what to do.
    sign_in users(:boris)
    get ticket_url(ticket)
    assert_select ".composer", 0
    assert_select ".callout", /This ticket is closed/

    # The full audit history, oldest first.
    actions = ticket.events.map(&:action)
    assert_equal %w[created priority_changed assignee_changed noted replied status_changed replied status_changed
                    replied status_changed status_changed], actions
  end

  test "an administrator brings a new requester on board" do
    sign_in users(:admin)
    post admin_users_url, params: { user: { name: "Eve New", email: "eve@example.com", password: "s3cret-pass",
                                            password_confirmation: "s3cret-pass", role: "requester" } }
    eve = User.find_by!(email: "eve@example.com")

    sign_in eve
    get new_ticket_url
    assert_select ".callout", /not part of an organization/

    sign_in users(:admin)
    post admin_organization_memberships_url(organizations(:globex)), params: { membership: { user_id: eve.id } }

    sign_in eve
    post tickets_url, params: { ticket: { subject: "Forklift battery", description: "Will not charge." } }
    ticket = Ticket.order(:number).last
    assert_equal organizations(:globex), ticket.organization
    get tickets_url
    assert_select "a.ticket-link", text: "Forklift battery"
    get ticket_url(tickets(:vpn))
    assert_response :not_found
  end
end
