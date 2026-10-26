require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  test "sign in is required" do
    get tickets_url
    assert_redirected_to new_user_session_url
  end

  test "staff get the queue with views and filters" do
    sign_in users(:agent)
    get root_url
    assert_response :success
    assert_select "h1", "Queue"
    assert_select ".queue__views .view-link[aria-current=page]", /All unsolved/
    assert_select ".tickets-table tbody tr", 3
    assert_select ".menubar a.nav-link[aria-current=page]", /Queue/

    get tickets_url(view: "all", q: "vpn")
    assert_select ".tickets-table tbody tr", 1
    assert_select "#ticket_#{tickets(:vpn).id} .pill--urgent"
    assert_select "#ticket_#{tickets(:vpn).id} .avatar[aria-hidden=true]"
  end

  test "the queue is coloured by view and its filters apply without a button" do
    sign_in users(:agent)
    get tickets_url(view: "solved", priority: "urgent", q: "vpn", sort: "created", page: 2)
    assert_select ".queue__views .view-link.sticky--green[aria-current=page]", /Solved/
    assert_select ".queue__list.sticky--green"
    assert_select "form.filters" do
      assert_select "input[type=hidden][name=view][value=solved]"
      assert_select "input[type=hidden][name=q][value=vpn]"
      assert_select "input[type=search]", 0
      assert_select "select.is-set", 1
      assert_select "select#priority.is-set"
      assert_select "noscript input[type=submit]"
      assert_select "> input[type=submit], .filters__actions > input[type=submit]", 0
    end
  end

  test "the menu bar search keeps the list's view and filters but not the page" do
    sign_in users(:agent)
    get tickets_url(view: "solved", priority: "urgent", q: "vpn", sort: "created", page: 2)
    assert_select ".menubar form.menubar__search[role=search][action='#{tickets_path}'][method=get]" do
      assert_select "input#menubar-q[type=search][name=q][value=vpn]"
      assert_select "input[type=hidden][name=view][value=solved]"
      assert_select "input[type=hidden][name=priority][value=urgent]"
      assert_select "input[type=hidden][name=sort][value=created]"
      assert_select "input[name=q][type=hidden]", 0
      assert_select "input[name=page]", 0
    end
    assert_select "label[for=menubar-q]"
  end

  test "the menu bar search on other pages searches all tickets" do
    sign_in users(:anna)
    get ticket_url(tickets(:printer))
    assert_select ".menubar form.menubar__search" do
      assert_select "input[type=hidden]", 1
      assert_select "input[type=hidden][name=view][value=all]"
      assert_select "input#menubar-q:not([value])"
    end

    get tickets_url(view: "solved")
    assert_select ".tabs .tab.sticky--green[aria-current=page]"
    assert_select "section.panel.sticky--green"
    assert_select ".panel input[type=search]", 0
  end

  test "requesters get only their own tickets" do
    sign_in users(:anna)
    get tickets_url(view: "all")
    assert_response :success
    assert_select "h1", "My tickets"
    assert_select ".tickets-table tbody tr", 2
    assert_select "a", text: tickets(:email_account).subject, count: 0
    assert_select "a", text: tickets(:vpn).subject, count: 0
    assert_select ".queue__views", 0
  end

  test "requesters without an organization are told to ask an administrator" do
    sign_in users(:drifter)
    get tickets_url
    assert_select ".callout", /not part of an organization/
    get new_ticket_url
    assert_select "form.stack-form", 0
  end

  test "a requester cannot see another requester's ticket in the same or another organization" do
    # A 404 response does not keep the test sign-in, so sign in each time.
    [ tickets(:printer), tickets(:vpn), 999_999 ].each do |ticket|
      sign_in users(:boris)
      get ticket_url(id: ticket.to_param)
      assert_response :not_found
    end
  end

  test "the requester's page has no internal notes or internal events" do
    sign_in users(:anna)
    get ticket_url(tickets(:printer))
    assert_response :success
    assert_no_match "STAFF-ONLY", response.body
    assert_match comments(:printer_reply).body, response.body
    assert_no_match "assigned the ticket", response.body
    assert_no_match "changed the priority", response.body
    assert_select ".message--internal", 0
    assert_select "form.properties-form", 0
    assert_select ".composer .composer__mode", 0
    assert_select "form[action=?]", resolve_ticket_path(tickets(:printer))
  end

  test "staff see internal notes and events" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select ".message--internal", /STAFF-ONLY/
    assert_match "assigned the ticket to Maria Agent", response.body
    assert_select "form.properties-form select[name='ticket[status]'] option", 4 # open + 3 transitions
    assert_select ".composer input[name='comment[internal]']", 2
  end

  test "a requester opens a ticket; staff-only fields are ignored" do
    sign_in users(:anna)
    assert_difference "Ticket.count" do
      post tickets_url, params: { ticket: { subject: "Oven alarm keeps beeping", description: "Since Monday.",
                                            status: "closed", priority: "urgent", assignee_id: users(:agent).id,
                                            requester_id: users(:boris).id, files: [ upload ] } }
    end
    ticket = Ticket.order(:number).last
    assert_redirected_to ticket_url(ticket)
    assert_equal [ "new", "normal", nil, users(:anna), organizations(:acme) ],
                 [ ticket.status, ticket.priority, ticket.assignee, ticket.requester, ticket.organization ]
    assert ticket.files.attached?
    follow_redirect!
    assert_select ".flash", /Ticket ##{ticket.number} was created/
  end

  test "a requester cannot open a ticket for an organization they do not belong to" do
    sign_in users(:anna)
    assert_no_difference "Ticket.count" do
      post tickets_url, params: { ticket: { subject: "x", description: "y", organization_id: organizations(:globex).id } }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /not a member/
  end

  test "a requester without an organization cannot open a ticket" do
    sign_in users(:drifter)
    assert_no_difference "Ticket.count" do
      post tickets_url, params: { ticket: { subject: "x", description: "y" } }
    end
    assert_response :unprocessable_content
  end

  test "invalid tickets re-render the form with errors" do
    sign_in users(:anna)
    post tickets_url, params: { ticket: { subject: "", description: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors li", 2
    assert_select "#ticket_subject[aria-invalid=true]"
  end

  test "the staff form lists each requester's organizations for the organization select" do
    sign_in users(:agent)
    get new_ticket_url
    assert_select "select#ticket_requester_id[data-requester-organizations=ticket_organization_id]" do
      assert_select "option[value='#{users(:anna).id}'][data-organizations='#{organizations(:acme).id}']"
      assert_select "option[value='#{users(:carl).id}'][data-organizations='#{organizations(:globex).id}']"
    end
    assert_select "#organization-hint[data-choose-text]"
  end

  test "staff open a ticket for a requester with priority and assignee" do
    sign_in users(:agent)
    get new_ticket_url
    assert_select "select[name='ticket[requester_id]']"
    post tickets_url, params: { ticket: { subject: "Phone call: scale broken", description: "Called at 9:00.",
                                          requester_id: users(:carl).id, organization_id: organizations(:globex).id,
                                          priority: "high", assignee_id: users(:agent_two).id } }
    ticket = Ticket.order(:number).last
    assert_equal [ users(:carl), "high", users(:agent_two) ], [ ticket.requester, ticket.priority, ticket.assignee ]
    assert_equal users(:agent), ticket.events.first.actor
  end

  test "staff update status, priority and assignee" do
    sign_in users(:agent)
    patch ticket_url(tickets(:email_account)), params: { ticket: { status: "pending", priority: "low",
                                                                   assignee_id: users(:agent).id } }
    assert_redirected_to ticket_url(tickets(:email_account))
    ticket = tickets(:email_account).reload
    assert_equal [ "pending", "low", users(:agent) ], [ ticket.status, ticket.priority, ticket.assignee ]
  end

  test "an invalid update re-renders the ticket" do
    sign_in users(:agent)
    patch ticket_url(tickets(:old_question)), params: { ticket: { status: "pending" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /cannot change from Closed to Pending/
  end

  test "requesters cannot update properties" do
    sign_in users(:anna)
    patch ticket_url(tickets(:printer)), params: { ticket: { status: "closed", assignee_id: "" } }
    assert_response :forbidden
    assert_equal "open", tickets(:printer).reload.status
    assert_equal users(:agent), tickets(:printer).assignee
  end

  test "requesters cannot update tickets they cannot see" do
    sign_in users(:boris)
    patch ticket_url(tickets(:printer)), params: { ticket: { status: "closed" } }
    assert_response :not_found
  end

  test "a requester marks their ticket as resolved" do
    sign_in users(:anna)
    patch resolve_ticket_url(tickets(:printer))
    assert_redirected_to ticket_url(tickets(:printer))
    assert_equal "resolved", tickets(:printer).reload.status
    assert_equal users(:anna), tickets(:printer).events.last.actor

    patch resolve_ticket_url(tickets(:old_question))
    assert_response :forbidden
  end

  test "Bulgarian pages" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer)), headers: { "Accept-Language" => "bg" }
    assert_select "html[lang=bg]"
    assert_select ".pill--status", "В процес"
    get tickets_url, headers: { "Accept-Language" => "bg,en;q=0.8" }
    assert_select "h1", "Опашка"
  end
end
