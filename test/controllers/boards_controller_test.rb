require "test_helper"

# The kanban board (specs/board.md).
class BoardsControllerTest < ActionDispatch::IntegrationTest
  test "staff see one column per status with counts and cards" do
    sign_in users(:agent)
    get board_url
    assert_response :success
    assert_select ".board-column[data-status]", Ticket::STATUSES.size
    assert_select ".board-column[data-status=done].is-collapsed"
    assert_select ".board-column[data-status=done] .board-pill__label", "Done"
    assert_select ".board-column[data-status=open]:not(.is-collapsed)"
    open_count = Ticket.where(status: "open").count
    assert_select ".board-column[data-status=open] .board-column__count", open_count.to_s
    assert_select ".board-column[data-status=open] .board-pill__count", open_count.to_s

    printer = tickets(:printer)
    assert_select "#card_ticket_#{printer.id}[draggable=true][data-allowed=?][data-move-url=?]",
                  Ticket::TRANSITIONS[printer.status].join(" "), move_ticket_path(printer) do
      assert_select ".board-card__number", printer.reference
      assert_select ".board-card__org", printer.organization.name
      assert_select ".board-card__title a[href=?]", ticket_path(printer)
      assert_select ".board-card__people", /#{printer.requester.display_name}.*#{printer.assignee.display_name}/m
      assert_select ".board-card__move form[action=?]", move_ticket_path(printer), Ticket::TRANSITIONS[printer.status].size
    end
    assert_select ".view-switch a[aria-current=page]", "Board"
    assert_select ".menubar__nav a[aria-current=page][href=?]", board_path, /Board/
    assert_select ".menubar__nav a[aria-current=page]", 1
    assert_select "turbo-cable-stream-source[channel=TicketListsChannel]"
  end

  test "urgent cards are golden and first in their column" do
    tickets(:printer).update_columns(priority: "urgent", updated_at: 1.year.ago)
    Ticket.create!(subject: "Fresh", description: "x", requester: users(:anna), organization: organizations(:acme),
                   actor: users(:agent), status: "new").update_columns(status: "open")
    sign_in users(:agent)
    get board_url
    first = css_select(".board-column[data-status=open] .board-card").first
    assert_equal "card_ticket_#{tickets(:printer).id}", first["id"]
    assert_includes first["class"], "is-golden"
  end

  test "the done column shows at most 50 cards with a link to the rest" do
    52.times do |i|
      Ticket.create!(subject: "Old #{i}", description: "x", requester: users(:anna), organization: organizations(:acme),
                     actor: users(:agent)).update_columns(status: "done")
    end
    sign_in users(:agent)
    get board_url
    assert_select ".board-column[data-status=done] .board-card", 50
    total = Ticket.where(status: "done").count
    assert_select ".board-column[data-status=done] .board-column__count", total.to_s
    assert_select ".board-column[data-status=done] .board-column__more a[href=?]", tickets_path(view: "done"), /and #{total - 50} more/
  end

  test "filters narrow the board" do
    sign_in users(:agent)
    get board_url(organization: organizations(:globex).id)
    assert_select ".board-card__org", text: organizations(:acme).name, count: 0
    assert_select "select[name=organization].is-set"
  end

  test "the board has the list's filters: status, priority, assignee, organization and sort" do
    sign_in users(:agent)
    get board_url
    %w[status priority assignee organization sort].each { |name| assert_select "form.board-filters select[name=?]", name }
    assert_select "form.board-filters input[name=view]", 0
    assert_select ".advanced-search", 0, "advanced search belongs to the queue (specs/queues.md)"

    get board_url(status: "open", q: "printer")
    assert_select ".board-column[data-status]:not(.board-column--stage)", 1
    assert_select ".board-column[data-status=open] .board-card", 1
    assert_select "form.board-filters input[type=hidden][name=q][value=printer]"
    assert_select "select[name=status].is-set"
    assert_select ".filters__clear[href=?]", board_path

    get board_url(priority: "urgent")
    assert_select ".board-card", 1
    assert_select ".board-column[data-status=pending] .board-card", 1
  end

  test "the sort orders cards after golden ones" do
    Ticket.update_all(status: "open")
    Ticket.update_all(priority: "normal")
    tickets(:printer).update_columns(created_at: 1.day.ago, updated_at: 1.minute.ago)
    tickets(:vpn).update_columns(created_at: 1.hour.ago, updated_at: 1.year.ago)
    sign_in users(:admin)
    get board_url(sort: "created")
    assert_equal tickets(:vpn).reference, css_select(".board-column[data-status=open] .board-card__number").first.text.strip
    get board_url
    assert_equal tickets(:printer).reference, css_select(".board-column[data-status=open] .board-card__number").first.text.strip
  end

  test "a move sent as POST with _method, as the board script does, works" do
    ticket = tickets(:printer)
    sign_in users(:agent)
    post move_ticket_url(ticket), params: { _method: "patch", status: "pending", stage: "" },
                                  headers: { "Accept" => "application/json" }
    assert_response :no_content
    assert_equal "pending", ticket.reload.status
  end

  test "requesters may not open the board; the queue links to it" do
    sign_in users(:anna)
    get board_url
    assert_response :forbidden
    sign_in users(:agent)
    get tickets_url
    assert_select ".view-switch a[href=?]", board_path
  end

  test "stages are columns after their status; cards move into them; requesters never see stages" do
    stage = Stage.create!(status: "open", name: "Investigating", color: "pink")
    ticket = tickets(:printer)
    sign_in users(:agent)
    get board_url
    assert_select ".board-column--stage[data-status=open][data-stage=?] .board-column__title", stage.id.to_s, /In progress \/\s*Investigating/
    keys = css_select("[data-board-column]").map { |column| column["data-key"] }
    assert_equal keys.index("open") + 1, keys.index("stage-#{stage.id}")
    assert_select "#card_ticket_#{ticket.id} .board-card__move-option", text: "In progress / Investigating"

    patch move_ticket_url(ticket), params: { status: "open", stage: stage.id }, headers: { "Accept" => "application/json" }
    assert_response :no_content
    assert_equal stage, ticket.reload.stage
    get board_url
    assert_select "[data-stage='#{stage.id}'] #card_ticket_#{ticket.id}"
    get tickets_url
    assert_select ".stage-tag", /Investigating/
    get ticket_url(ticket)
    assert_select "select[name='ticket[stage_id]'] option[selected]", "Investigating"

    sign_in users(:anna)
    get ticket_url(ticket)
    assert_not_includes response.body, "Investigating"
  end
end
