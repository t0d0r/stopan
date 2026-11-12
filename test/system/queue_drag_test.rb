require "application_system_test_case"

# Dragging rows of the queue onto a view tab (specs/queues.md "Dragging onto a view").
class QueueDragTest < ApplicationSystemTestCase
  setup do
    @tickets = 3.times.map do |i|
      Ticket.create!(subject: "Numbat #{i}", description: "x", requester: users(:anna), organization: organizations(:acme), actor: users(:anna))
    end
    sign_in_as users(:agent)
    visit tickets_path(view: "all", q: "Numbat")
    assert_selector "tr.ticket-row", count: 3
  end

  def row(ticket) = find("tr##{ActionView::RecordIdentifier.dom_id(ticket)}")

  # HTML5 drag and drop as the browser fires it, with one DataTransfer.
  def drag(ticket, to:)
    page.execute_script(<<~JS, ActionView::RecordIdentifier.dom_id(ticket), to)
      const row = document.getElementById(arguments[0]);
      const tab = document.querySelector(`.view-link[href*="view=${arguments[1]}"]`);
      const data = new DataTransfer();
      const fire = (target, type) => target.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer: data }));
      fire(row, "dragstart");
      fire(tab, "dragover");
      fire(tab, "drop");
      fire(row, "dragend");
    JS
  end

  test "a row dropped on Done is marked done, alone" do
    drag(@tickets[0], to: "done")
    assert_text "1 ticket changed."
    assert_current_path(/\A\/tickets\?.*q=Numbat/)
    assert_equal %w[done new new], @tickets.map { |ticket| ticket.reload.status }
  end

  test "a ticked row takes every ticked row; Assigned to me assigns them" do
    row(@tickets[0]).find("[data-bulk-row]").click
    row(@tickets[2]).find("[data-bulk-row]").click
    drag(@tickets[2], to: "mine")
    assert_text "2 tickets changed."
    assert_equal [ users(:agent).id, nil, users(:agent).id ], @tickets.map { |ticket| ticket.reload.assignee_id }
  end

  test "an unticked row is dragged alone, whatever is ticked" do
    row(@tickets[0]).find("[data-bulk-row]").click
    drag(@tickets[1], to: "pending")
    assert_text "1 ticket changed."
    assert_equal %w[new pending new], @tickets.map { |ticket| ticket.reload.status }
  end

  test "All unsolved reopens done rows and takes no others; All tickets takes nothing" do
    @tickets[0].apply_changes!({ status: "done" }, actor: users(:agent))
    visit tickets_path(view: "all", q: "Numbat")
    drag(@tickets[1], to: "all")
    drag(@tickets[1], to: "unsolved")
    assert_equal "new", @tickets[1].reload.status
    assert_no_text "changed."

    drag(@tickets[0], to: "unsolved")
    assert_text "1 ticket changed."
    assert_equal "open", @tickets[0].reload.status
  end

  test "while dragging, the tabs that take the drop are outlined inside themselves, apart from each other" do
    page.execute_script(<<~JS, ActionView::RecordIdentifier.dom_id(@tickets[0]))
      const row = document.getElementById(arguments[0]);
      row.dispatchEvent(new DragEvent("dragstart", { bubbles: true, cancelable: true, dataTransfer: new DataTransfer() }));
    JS
    assert_selector ".queue__views.is-taking-rows .view-link.is-drop", minimum: 5
    # The outline plus its offset stays within the tab's box, so two neighbours cannot overlap.
    reach = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".view-link.is-drop")].map((tab) => {
        const style = getComputedStyle(tab);
        return parseFloat(style.outlineWidth) + parseFloat(style.outlineOffset);
      })
    JS
    assert reach.all? { |value| value <= 0 }, reach.inspect
  end
end
