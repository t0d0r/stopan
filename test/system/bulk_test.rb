require "application_system_test_case"

# Bulk actions in a browser (specs/queues.md "Bulk actions").
class BulkTest < ApplicationSystemTestCase
  test "a super administrator deletes selected tickets from the search results" do
    ticket = tickets(:printer)
    sign_in_as users(:admin)
    visit search_path(q: ticket.subject.split.first)
    find("tr##{ActionView::RecordIdentifier.dom_id(ticket)} input[data-bulk-row]").click
    within("#bulk-form") { click_button "Delete" }
    within("dialog[open]") { find("[data-confirm-ok]").click }
    assert_no_selector "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"
    assert ticket.reload.deleted?
  end

  test "deleting after searching on the search page itself, without a full page load" do
    ticket = tickets(:printer)
    sign_in_as users(:admin)
    visit search_path
    assert_no_selector "#bulk-form"
    fill_in "q", with: ticket.subject.split.first, match: :first
    find("input[name=q]", match: :first).send_keys(:enter)
    assert_selector "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"

    find("tr##{ActionView::RecordIdentifier.dom_id(ticket)} input[data-bulk-row]").click
    assert_selector "[data-bulk-count]", text: "1 selected"
    within("#bulk-form") { click_button "Delete" }
    assert_selector "dialog[open]"
    within("dialog[open]") { find("[data-confirm-ok]").click }
    assert_no_selector "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"
    assert ticket.reload.deleted?
  end

  test "deleting selected tickets from the search results" do
    ticket = tickets(:printer)
    sign_in_as users(:agent)
    visit search_path(q: ticket.subject.split.first)
    assert_selector "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"

    find("tr##{ActionView::RecordIdentifier.dom_id(ticket)} input[data-bulk-row]").click
    assert_selector "#bulk-form:not([hidden])"
    within("#bulk-form") { click_button "Delete" }
    assert_selector "dialog[open]"
    within("dialog[open]") { find("[data-confirm-ok]").click }

    assert_no_selector "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"
    assert ticket.reload.deleted?
  end

  test "deleting the whole page and the whole list from the search results" do
    30.times do |i|
      Ticket.create!(subject: "Zebra crossing #{i}", description: "x", requester: users(:anna), organization: organizations(:acme),
                     actor: users(:anna))
    end
    sign_in_as users(:agent)
    visit search_path(q: "Zebra")
    assert_selector "tr.ticket-row", count: 25

    find("input[data-bulk-page]").click
    assert_selector "#bulk-form:not([hidden])"
    find("[data-bulk-all]").click
    within("#bulk-form") { click_button "Delete" }
    within("dialog[open]") { find("[data-confirm-ok]").click }

    assert_text "Search"
    assert_no_selector "tr.ticket-row"
    assert_equal 30, Ticket.where("subject LIKE ?", "Zebra%").where.not(deleted_at: nil).count
  end

  test "shift+click ticks and clears a range of rows, and the bar counts them" do
    8.times do |i|
      Ticket.create!(subject: "Quokka #{i}", description: "x", requester: users(:anna), organization: organizations(:acme), actor: users(:anna))
    end
    sign_in_as users(:agent)
    visit search_path(q: "Quokka")
    boxes = all("input[data-bulk-row]")
    assert_equal 8, boxes.size

    boxes[1].click
    boxes[5].click(:shift)
    assert_equal [ false, true, true, true, true, true, false, false ], all("input[data-bulk-row]").map(&:checked?)
    assert_selector "[data-bulk-count]", text: "5 selected"
    assert_selector "tr.ticket-row.is-selected", count: 5

    boxes[3].click(:shift)   # clears from the last one clicked (5) back to 3
    assert_equal [ false, true, true, false, false, false, false, false ], all("input[data-bulk-row]").map(&:checked?)
    assert_selector "[data-bulk-count]", text: "2 selected"

    boxes[7].click           # a plain click only ticks its own box
    assert_equal [ false, true, true, false, false, false, false, true ], all("input[data-bulk-row]").map(&:checked?)
  end

  test "shift+click works in the member picker and skips rows the search hides" do
    names = %w[Alfa Bravo Charlie Delta Echo]
    names.each { |name| User.create!(name: "#{name} Picker", email: "#{name.downcase}@picker.example", password: "password12", role: "requester") }
    sign_in_as users(:admin)
    visit admin_organization_path(organizations(:globex))
    picker = find("[data-member-picker]")
    box = ->(name) { picker.find("[data-picker-row]", text: "#{name} Picker").find("input[type=checkbox]") }

    # Narrowed to the five; the other candidates are hidden and stay untouched.
    picker.find("[data-picker-search]").set("Picker")
    assert_equal 5, picker.all("[data-picker-row]").size
    box.call("Alfa").click
    box.call("Delta").click(:shift)
    picker.find("[data-picker-search]").set("")
    ticked = picker.all("[data-picker-row]").select { |row| row.find("input[type=checkbox]").checked? }.map { |row| row.text[/\w+ Picker/] }
    assert_equal [ "Alfa Picker", "Bravo Picker", "Charlie Picker", "Delta Picker" ], ticked
    assert_match(/4/, picker.find("[data-picker-submit]").value)
  end

  test "deleting from an advanced search with its long address comes back to the same search" do
    ticket = tickets(:printer)
    sign_in_as users(:admin)
    visit "/search?q=&status=&priority=&assignee=&organization=&sort=updated&words=&requester_q=#{ticket.requester.name.split.first}" \
          "&created_from=&created_to=&updated_from=&updated_to=&source="
    row = "tr##{ActionView::RecordIdentifier.dom_id(ticket)}"
    assert_selector row
    find("#{row} input[data-bulk-row]").click
    within("#bulk-form") { click_button "Delete" }
    within("dialog[open]") { find("[data-confirm-ok]").click }

    assert_no_selector row
    assert_current_path(/\A\/search\?.*requester_q=/)
    assert ticket.reload.deleted?
  end
end
