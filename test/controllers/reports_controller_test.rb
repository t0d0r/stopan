require "test_helper"

# The reports page (specs/reports.md).
class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "requesters may not open it; staff get the pill" do
    sign_in users(:anna)
    get reports_url
    assert_response :forbidden
    get tickets_url
    assert_select ".menubar__nav a[href=?]", reports_path, 0

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
    assert_select "[data-report-chart] .report-legend li", 2
    assert_select "[data-report-chart] g[data-chart-group]", 30
    assert_select "[data-report-chart] g[data-chart-group] title", 30
    assert_select "[data-report-chart] details table tbody tr", 30
    assert_select ".report-meter", minimum: 4
    assert_select "#report-org-title"
    assert_select ".report-table .report-table__name", /Maria Agent/
    assert_select "select[name=period] option[selected][value='30d']"
  end

  test "period and organization filters, with fallbacks" do
    sign_in users(:agent)
    get reports_url(period: "12m", organization: organizations(:globex).id)
    assert_select "[data-report-chart] g[data-chart-group]", 12
    assert_select "select[name=organization].is-set option[selected]", organizations(:globex).name
    assert_select ".report-table .report-table__name", text: organizations(:acme).name, count: 0

    get reports_url(period: "forever", organization: "999999")
    assert_select "select[name=period] option[selected][value='30d']"
    assert_select "select[name=organization]:not(.is-set)"
  end

  test "renders in Bulgarian and German" do
    sign_in users(:agent)
    get reports_url, headers: { "Accept-Language" => "bg" }
    assert_select "h1", "Отчети"
    users(:agent).update!(language: "de")
    get reports_url
    assert_select "h1", "Berichte"
    assert_select ".report-legend li", /Erledigt/
  end
end
