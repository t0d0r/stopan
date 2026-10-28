require "test_helper"

# The search page with advanced search (specs/queues.md "Search page", "Advanced search").
class AdvancedSearchTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:agent) }

  def numbers(**params)
    get search_url(**params)
    css_select("td.ticket-number").map { |cell| cell.text.strip }.sort
  end

  test "the search page is a menu bar section with the text field and advanced search shown" do
    get search_url
    assert_response :success
    assert_select ".menubar__nav a.nav-link[aria-current=page][href=?]", search_path
    assert_select "form.filters[action=?] input[type=search][name=q]", search_path
    assert_select "section.advanced-search input[name=words]"
    assert_select "details.advanced-search", 0
    assert_select ".panel__empty", I18n.t("ui.search.prompt", locale: :en)
    assert_select "table.tickets-table", 0

    get search_url(words: "printer blank", source: "email")
    assert_select "section.advanced-search h2 .tab__count", "2"
    assert_select "input[name=words][value='printer blank']"
    assert_select "select[name=source] option[selected][value=email]"
    assert_select "form.menubar__search", 0, "the page has its own search field"
    get search_url(words: "printer")
    assert_select "#bulk-form input[name='list[words]'][value=printer]"
    assert_select "#bulk-form input[name=return_to][value=?]", "/search?words=printer"
  end

  test "the queue and the board have no advanced search; the quick search does not carry it there" do
    get tickets_url(view: "all", words: "printer")
    assert_select ".advanced-search", 0
    assert_select "form.menubar__search[action=?]", tickets_path
    assert_select "form.menubar__search input[name=words]", 0
    get board_url
    assert_select ".advanced-search", 0
  end

  test "bulk actions return to the search page" do
    patch bulk_tickets_url, params: { numbers: [ tickets(:printer).number ], changes: { priority: "high" },
                                      return_to: "/search?words=printer" }
    assert_redirected_to "/search?words=printer"
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

  test "requesters do not get advanced fields or the search page" do
    sign_in users(:anna)
    get search_url
    assert_response :forbidden
    get tickets_url
    assert_select "a.nav-link[href=?]", search_path, 0
    get tickets_url(view: "all", words: "zzz-nothing")
    assert_equal %w[#1001 #1004], css_select("td.ticket-number").map { |cell| cell.text.strip }.sort
  end
end
