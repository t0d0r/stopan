require "application_system_test_case"

# The pages at a phone's width (specs/mobile.md).
class PhoneTest < ApplicationSystemTestCase
  setup { page.driver.resize(390, 800) }

  def assert_no_sideways_scroll
    widths = page.evaluate_script("[document.documentElement.scrollWidth, window.innerWidth]")
    assert_operator widths[0], :<=, widths[1], "the page scrolls sideways at #{current_path}"
  end

  test "the menu sits behind its button; the pages do not scroll sideways" do
    sign_in_as users(:agent)
    visit tickets_path
    assert_selector "[data-menu-toggle][aria-expanded=false]"
    assert_no_selector ".menubar.is-open"
    assert_no_sideways_scroll

    find("[data-menu-toggle]").click
    assert_selector ".menubar.is-open [data-menu-toggle][aria-expanded=true]"
    find("body").send_keys(:escape)
    assert_no_selector ".menubar.is-open"

    [ board_path, search_path(q: "printer"), reports_path ].each do |path|
      visit path
      assert_selector "h1"
      assert_no_sideways_scroll
    end
  end

  test "the composer opens from the Reply bar at the bottom" do
    sign_in_as users(:agent)
    visit ticket_path(tickets(:printer))
    assert_selector "[data-reply-open][aria-expanded=false]"
    assert_no_selector "#comment_body", visible: :visible
    assert_no_sideways_scroll

    find("[data-reply-open]").click
    assert_selector "#composer.is-open #comment_body"
    fill_in "comment_body", with: "Sent from a phone."
    find("[data-composer-submit]").click
    assert_selector ".timeline .message", text: "Sent from a phone."
  end

  test "the Status page names each value of its stacked rows" do
    MailboxEvent.create!(organization: organizations(:acme), result: "ticket", sender: "ivan@example.com", subject: "Bread slicer")
    sign_in_as users(:admin)
    visit admin_status_path
    assert_no_sideways_scroll
    label = page.evaluate_script("getComputedStyle(document.querySelector('#mail-log tbody td'), '::before').content")
    assert_equal "\"When: \"", label
    assert_equal "block", page.evaluate_script("getComputedStyle(document.querySelector('#mail-log tbody td')).display")
  end
end
