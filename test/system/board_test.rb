require "application_system_test_case"

# Several cards at once on the board (specs/board.md "Several cards at once").
class BoardTest < ApplicationSystemTestCase
  setup do
    @tickets = 4.times.map do |i|
      Ticket.create!(subject: "Wombat #{i}", description: "x", requester: users(:anna), organization: organizations(:acme), actor: users(:anna))
    end
    sign_in_as users(:agent)
    visit board_path(q: "Wombat")
    assert_selector "[data-board-card]", count: 4
  end

  def card(ticket) = find("##{ActionView::RecordIdentifier.dom_id(ticket, :card)}")

  # HTML5 drag and drop as the browser fires it, with one DataTransfer.
  def drag(ticket, to:)
    page.execute_script(<<~JS, ActionView::RecordIdentifier.dom_id(ticket, :card), to)
      const card = document.getElementById(arguments[0]);
      const column = document.querySelector(`[data-board-column][data-status="${arguments[1]}"]:not([data-stage]), [data-board-column][data-status="${arguments[1]}"][data-stage=""]`);
      const data = new DataTransfer();
      const fire = (target, type) => target.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer: data }));
      fire(card, "dragstart");
      fire(column, "dragover");
      fire(column, "drop");
      fire(card, "dragend");
    JS
  end

  test "ticked cards are ringed and counted; shift+click ticks a range; Escape clears" do
    assert_no_selector "#board-bulk:not([hidden])", visible: :all
    card(@tickets[3]).find("[data-board-check]").click
    assert_selector "#board-bulk", text: "1 selected"
    boxes = all("[data-board-check]")
    boxes.first.click
    boxes.last.click(:shift)
    assert_selector ".board-card.is-selected", count: 4
    assert_selector "#board-bulk", text: "4 selected"

    find("body").send_keys(:escape)
    assert_no_selector ".board-card.is-selected"
    assert_no_selector "#board-bulk:not([hidden])", visible: :all
  end

  test "dragging a ticked card moves every ticked card" do
    @tickets.first(3).each { |ticket| card(ticket).find("[data-board-check]").click }
    drag(@tickets.first, to: "open")

    # The empty column started collapsed, so its cards are there but not shown.
    assert_selector "[data-board-column][data-status=open] [data-board-card]", count: 3, visible: :all
    assert_selector "[data-board-column][data-status=open] [data-column-count]", text: "3", visible: :all
    assert_selector "[data-board-column][data-status=new] [data-board-card]", count: 1
    assert_no_selector ".board-card.is-selected"
    assert_equal %w[open open open new], @tickets.map { |ticket| ticket.reload.status }
    assert_equal 3, TicketEvent.where(ticket: @tickets, action: "status_changed", to_value: "open").count
  end

  test "an unticked card is dragged alone, whatever is ticked" do
    card(@tickets[0]).find("[data-board-check]").click
    card(@tickets[1]).find("[data-board-check]").click
    drag(@tickets[3], to: "open")
    assert_selector "[data-board-column][data-status=open] [data-board-card]", count: 1, visible: :all
    assert_equal %w[new new new open], @tickets.map { |ticket| ticket.reload.status }
    assert_selector ".board-card.is-selected", count: 2
  end

  test "cards that may not move there stay, and a notice counts them" do
    # A done ticket may only be reopened; a new one may go to Pending.
    @tickets[0].apply_changes!({ status: "done" }, actor: users(:agent))
    visit board_path(q: "Wombat")
    done = find("[data-board-column][data-status=done]", visible: :all)
    done.find("[data-board-toggle]", match: :first, visible: :all).click if done[:class].include?("is-collapsed")

    [ @tickets[0], @tickets[1] ].each { |ticket| card(ticket).find("[data-board-check]").click }
    drag(@tickets[1], to: "pending")
    assert_text "1 of 2 tickets could not be moved there."
    assert_equal %w[done pending], @tickets.first(2).map { |ticket| ticket.reload.status }
    assert_no_selector ".board-card.is-selected"
  end

  test "the bar moves the ticked cards without dragging and comes back to the board" do
    @tickets.first(2).each { |ticket| card(ticket).find("[data-board-check]").click }
    within("#board-bulk") do
      select "Pending", from: "board_bulk_status"
      click_button "Move"
    end
    assert_current_path(/\A\/tickets\/board\?q=Wombat/)
    assert_text "2 tickets changed."
    assert_equal %w[pending pending new new], @tickets.map { |ticket| ticket.reload.status }
  end
end
