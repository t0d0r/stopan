require "test_helper"

# The reports page (specs/reports.md).
class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "requesters may not open it; staff get the pill" do
    sign_in users(:anna)
    get reports_url
    assert_response :forbidden
    get tickets_url
    assert_select ".menubar__nav a[href=?]", reports_path, 0
    assert_select ".menubar__nav a[href=?]", board_path, 0

    sign_in users(:agent)
    get tickets_url
    assert_select ".menubar__nav a[href=?]", reports_path, /Reports/
  end

  test "staff see tiles, the chart with legend, titles and table, and the tables" do
    tickets(:printer).add_comment(author: users(:agent), body: "On it.")
    sign_in users(:agent)
    get reports_url
    assert_response :success
    assert_select ".menubar__nav a[aria-current=page][href=?]", reports_path
    assert_select ".report-tile", 5
    assert_select ".report-tile__note", /vs the 30 days before/
    assert_select "[data-report-chart]:not(.report-chart--burndown) .report-legend li", 2
    assert_select "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group]", 30
    assert_select "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group] title", 30
    assert_select "[data-report-chart]:not(.report-chart--burndown) details table tbody tr", 30
    assert_select ".report-meter", minimum: 4
    assert_select "#report-org-title"
    assert_select ".report-table .report-table__name", /Maria Agent/
    assert_select "select[name=period] option[selected][value='30d']"

    assert_select ".report-chart--burndown g[data-chart-group]", 30
    assert_select ".report-chart--burndown polyline.report-chart__line"
    assert_select ".report-chart--burndown .report-chart__end", "#{Ticket.visible_to(users(:agent)).where.not(status: "done").count} open now"
    assert_select ".report-chart--burndown .report-legend", 0
    assert_select ".report-chart--burndown details table tbody tr", 30
  end

  test "period and organization filters, with fallbacks" do
    sign_in users(:agent)
    get reports_url(period: "12m", organization: organizations(:globex).id)
    assert_select "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group]", 12
    assert_select "select[name=organization].is-set option[selected]", organizations(:globex).name
    assert_select ".report-table .report-table__name", text: organizations(:acme).name, count: 0

    get reports_url(period: "forever", organization: "999999")
    assert_select "select[name=period] option[selected][value='30d']"
    assert_select "select[name=organization]:not(.is-set)"
  end

  test "a custom range has date fields, an Apply button, its own links and file name" do
    sign_in users(:agent)
    get reports_url
    assert_select "select[name=period] option[value=custom]", "Custom range"
    assert_select "input[type=date]", 0
    assert_select "form.report-filters > input[type=submit]", 0

    today = Date.current
    get reports_url(period: "custom")
    assert_select "select[name=period] option[selected][value=custom]"
    assert_select "input[type=date][name=from][value=?][max=?]", (today - 29).iso8601, today.iso8601
    assert_select "input[type=date][name=to][value=?]", today.iso8601
    assert_select "label[for=from]", "From"
    assert_select "form.report-filters > input[type=submit][value=Apply]"
    assert_select ".report-range-note", 0

    from = (today - 13).iso8601
    to = today.iso8601
    get reports_url(period: "custom", from: from, to: to)
    assert_select ".report-tile__note", /vs the 14 days before/
    assert_select "[data-report-chart]:not(.report-chart--burndown) g[data-chart-group]", 14
    ReportCsv::TABLES.each do |table|
      assert_select "a.report-csv[href=?]", reports_path(format: :csv, table: table, period: "custom", from: from, to: to)
    end
    get reports_url(format: :csv, table: "volume", period: "custom", from: from, to: to)
    assert_match(/filename="stopan-volume-#{from}_#{to}-#{to}\.csv"/, response.headers["Content-Disposition"])

    get reports_url(period: "custom", from: to, to: from)
    assert_response :success
    assert_select ".report-range-note[role=status]", /not a valid range/
    assert_select "input[type=date][name=from][value=?]", (today - 29).iso8601
    assert_select ".report-tile__note", /vs the 30 days before/

    get reports_url(period: "custom", from: from, to: to), headers: { "Accept-Language" => "bg" }
    assert_select "select[name=period] option[selected]", "Избран период"
    assert_select ".report-tile__note", /предходните 14 дни/
  end

  test "renders in Bulgarian and German" do
    sign_in users(:agent)
    get reports_url, headers: { "Accept-Language" => "bg" }
    assert_select "h1", "Отчети"
    assert_select ".desk__header.report-header > h1 + form.report-filters select[name=period]"
    users(:agent).update!(language: "de")
    get reports_url
    assert_select "h1", "Berichte"
    assert_select ".report-legend li", /Erledigt/
  end

  def csv(table, **params)
    get reports_url(format: :csv, table: table, **params)
    response.body.delete_prefix("\uFEFF").split("\r\n").map { |line| line[1..-2].split('","', -1) }
  end

  test "each table downloads as CSV with the page's filters" do
    sign_in users(:agent)
    get reports_url(period: "7d", organization: organizations(:acme).id)
    ReportCsv::TABLES.each do |table|
      assert_select "a.report-csv[href=?]", reports_path(format: :csv, table: table, period: "7d", organization: organizations(:acme).id)
    end

    rows = csv("volume", period: "7d")
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.media_type + "; charset=" + response.charset.downcase
    assert_match(/attachment; filename="stopan-volume-7d-\d{4}-\d\d-\d\d\.csv"/, response.headers["Content-Disposition"])
    assert response.body.start_with?("\uFEFF")
    assert_equal %w[Day Created Done], rows.first
    assert_equal 8, rows.size
    assert_match(/\A\d{4}-\d\d-\d\d\z/, rows.last.first)

    assert_equal %w[Month Open], csv("burndown", period: "12m").first
    assert_equal %w[Status Stage Tickets], csv("statuses").first
    report = TicketReport.new(users(:agent), {})
    rows = csv("organizations")
    assert_equal [ "Organization", "New", "Done", "Open now", "First response (seconds)", "Resolution (seconds)" ], rows.first
    assert_equal report.organization_rows.map { |row| [ row.organization.name, row.open.to_s ] }, rows.drop(1).map { [ it[0], it[3] ] }
    rows = csv("people")
    assert_equal "Role", rows.first[1]
    assert_equal report.person_rows.map { |row| row.user.display_name }, rows.drop(1).map(&:first)
  end

  test "CSV cells that look like formulas are defused; requesters and unknown tables are refused" do
    organizations(:acme).update!(name: %(=HYPERLINK("http://x","y")))
    sign_in users(:agent)
    get reports_url(format: :csv, table: "organizations")
    assert_includes response.body, %("'=HYPERLINK(""http://x"",""y"")")

    get reports_url(format: :csv, table: "users")
    assert_response :not_found
    sign_in users(:anna)
    get root_url
    get reports_url(format: :csv, table: "volume")
    assert_response :forbidden
  end
end
