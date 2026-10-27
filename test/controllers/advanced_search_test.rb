require "test_helper"

# Advanced search in the queue (specs/queues.md "Advanced search").
class AdvancedSearchTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:agent) }

  def numbers(**params)
    get tickets_url(view: "all", **params)
    css_select("td.ticket-number").map { |cell| cell.text.strip }.sort
  end

  test "the disclosure is closed until a field is set, then open with the count, and keeps the values" do
    get tickets_url
    assert_select "details.advanced-search:not([open]) input[name=words]"
    get tickets_url(view: "all", words: "printer blank", source: "email")
    assert_select "details.advanced-search[open] summary .tab__count", "2"
    assert_select "input[name=words][value='printer blank']"
    assert_select "select[name=source] option[selected][value=email]"
    assert_select "form.menubar__search input[type=hidden][name=words][value='printer blank']"
    get tickets_url(view: "all", words: "printer")
    assert_select "#bulk-form input[name='list[words]'][value=printer]"
  end

  test "words in any order, also in replies when asked" do
    assert_equal [ "#1001" ], numbers(words: "pages printer")
    assert_empty numbers(words: "printer shiny")
    assert_equal [ "#1001" ], numbers(words: "printer shiny", in_comments: "1")
    assert_equal [ "#1001" ], numbers(q: "shiny side", in_comments: "1")
  end

  test "requester, dates, source and files" do
    assert_equal %w[#1001 #1004], numbers(requester_q: users(:anna).email.upcase.first(4))
    tickets(:vpn).update_columns(source: "email", created_at: Time.zone.parse("2026-01-10 12:00"))
    assert_equal [ "#1003" ], numbers(source: "email")
    assert_equal [ "#1003" ], numbers(created_from: "2026-01-10", created_to: "2026-01-10")
    assert_empty numbers(created_from: "2026-01-11", created_to: "2026-01-11")
    assert_equal numbers, numbers(created_from: "not-a-date")

    perform_enqueued_jobs { tickets(:old_question).add_comment(author: users(:agent), body: "See file", files: [ fixture_file_upload("dot.png", "image/png") ]) }
    assert_equal [ "#1004" ], numbers(files: "1")
  end

  test "requesters do not get advanced fields" do
    sign_in users(:anna)
    get tickets_url(view: "all", words: "zzz-nothing")
    assert_equal %w[#1001 #1004], css_select("td.ticket-number").map { |cell| cell.text.strip }.sort
  end
end
