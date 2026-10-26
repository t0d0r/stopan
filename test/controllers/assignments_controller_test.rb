require "test_helper"

# One-click assignment (specs/tickets.md "Assigning", specs/queues.md).
class AssignmentsControllerTest < ActionDispatch::IntegrationTest
  test "taking a new ticket assigns it to me, starts work and goes back to the queue" do
    sign_in users(:agent)
    ticket = tickets(:email_account)
    queue = tickets_url(view: "unassigned", sort: "priority")
    patch assign_ticket_url(ticket), params: { assignee_id: users(:agent).id }, headers: { "Referer" => queue }

    assert_redirected_to queue
    assert_equal "Ticket #1002 is now assigned to you.", flash[:notice]
    ticket.reload
    assert_equal users(:agent), ticket.assignee
    assert_equal "open", ticket.status
    assert_equal %w[assignee_changed status_changed], ticket.events.where(actor: users(:agent)).pluck(:action).sort
  end

  test "assigning to someone else or to nobody keeps the status" do
    sign_in users(:agent)
    ticket = tickets(:email_account)
    patch assign_ticket_url(ticket), params: { assignee_id: users(:agent_two).id }
    assert_redirected_to ticket_url(ticket)
    assert_equal "Ticket #1002 is now assigned to Petar Agent.", flash[:notice]
    assert_equal [ users(:agent_two), "new" ], [ ticket.reload.assignee, ticket.status ]

    patch assign_ticket_url(ticket), params: { assignee_id: "" }
    assert_equal "Ticket #1002 is now unassigned.", flash[:notice]
    assert_nil ticket.reload.assignee
  end

  test "taking a ticket in progress only changes the assignee" do
    sign_in users(:agent_two)
    patch assign_ticket_url(tickets(:printer)), params: { assignee_id: users(:agent_two).id }
    assert_equal [ users(:agent_two), "open" ], [ tickets(:printer).reload.assignee, tickets(:printer).status ]
  end

  test "requesters, deactivated staff and unknown ids cannot be assigned" do
    sign_in users(:agent)
    ticket = tickets(:email_account)
    [ users(:anna).id, users(:retired).id, 0 ].each do |id|
      patch assign_ticket_url(ticket), params: { assignee_id: id }
      assert_equal "Tickets can only be assigned to active agents and administrators.", flash[:alert]
    end
    assert_nil ticket.reload.assignee
    assert_equal "new", ticket.status
  end

  test "a referer from another host is not followed" do
    sign_in users(:agent)
    patch assign_ticket_url(tickets(:email_account)), params: { assignee_id: users(:agent).id },
                                                      headers: { "Referer" => "https://evil.example/phish" }
    assert_redirected_to ticket_url(tickets(:email_account))
  end

  test "requesters cannot assign" do
    sign_in users(:anna)
    patch assign_ticket_url(tickets(:printer)), params: { assignee_id: users(:agent_two).id }
    assert_response :forbidden
    assert_equal users(:agent), tickets(:printer).reload.assignee
  end

  test "the queue has an assign menu per ticket and Take for unassigned unsolved tickets" do
    sign_in users(:agent)
    get tickets_url(view: "all")
    assert_select "#ticket_#{tickets(:email_account).id} details[data-assign-menu] form[action=?]",
                  assign_ticket_path(tickets(:email_account)) do
      assert_select "button[name=assignee_id][value='#{users(:agent).id}']", /Me/
      assert_select "button[name=assignee_id][value='#{users(:agent_two).id}']"
      assert_select "button[name=assignee_id][value='#{users(:retired).id}']", 0
      assert_select "button[name=assignee_id][value=''][disabled]"
    end
    assert_select "#ticket_#{tickets(:printer).id} button[name=assignee_id][value='#{users(:agent).id}'][disabled]"
    assert_select "#ticket_#{tickets(:email_account).id} form.button_to[action=?]", assign_ticket_path(tickets(:email_account))
    assert_select "#ticket_#{tickets(:printer).id} form.button_to", 0
    assert_select "#ticket_#{tickets(:vpn).id} form.button_to", 0
    assert_select "#ticket_#{tickets(:old_question).id} form.button_to", 0
  end

  test "the ticket page offers Take to staff when the ticket is not theirs" do
    sign_in users(:agent_two)
    get ticket_url(tickets(:printer))
    assert_select ".side-panel form.button_to[action=?] input[name=assignee_id][value=?]",
                  assign_ticket_path(tickets(:printer)), users(:agent_two).id.to_s

    sign_in users(:anna)
    get ticket_url(tickets(:printer))
    assert_select "form[action=?]", assign_ticket_path(tickets(:printer)), 0
  end
end
