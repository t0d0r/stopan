require "test_helper"

# specs/sla.md "Where it shows" and the settings panel.
class SlaPagesTest < ActionDispatch::IntegrationTest
  setup { @ticket = tickets(:printer) }

  def targets!(targets = { "urgent" => { "first_response" => 60, "resolution" => 480 } })
    AppSetting.current.update!(sla_targets: targets)
  end

  def urgent!(created: 3.hours.ago, **columns)
    @ticket.update_columns(priority: "urgent", status: "open", created_at: created, first_response_at: nil, done_at: nil, **columns)
  end

  test "a super administrator sets the targets in hours" do
    sign_in users(:admin)
    get admin_settings_url
    assert_select "#sla-targets table.sla-table tbody tr", 4
    assert_select "#sla-targets input[type=number][name='app_setting[sla_hours][urgent][first_response]'][step='0.25']"
    assert_select "#sla-targets tbody tr:first-child th", "Urgent"

    patch admin_settings_url, params: { app_setting: { sla_hours: { urgent: { first_response: "0.5", resolution: "8" },
                                                                    normal: { first_response: "", resolution: "48" } } } }
    assert_redirected_to admin_settings_url
    assert_equal({ "first_response" => 30, "resolution" => 480 }, AppSetting.current.sla_targets["urgent"])
    assert_equal 2880, AppSetting.current.sla_minutes("normal", "resolution")
    assert_nil AppSetting.current.sla_minutes("normal", "first_response")
    get admin_settings_url
    assert_select "#sla_urgent_first_response[value='0.5']"
    assert_select "#sla_urgent_resolution[value='8']"

    patch admin_settings_url, params: { app_setting: { sla_hours: { urgent: { first_response: "tomorrow" } } } }
    assert_response :unprocessable_content
    assert_select "#sla-targets", /SLA targets/
    assert_equal 30, AppSetting.current.sla_minutes("urgent", "first_response")
  end

  test "organization administrators and agents cannot set targets" do
    Membership.find_by!(user: users(:agent), organization: organizations(:acme)).update!(admin: true)
    sign_in users(:agent)
    patch admin_settings_url, params: { app_setting: { sla_hours: { urgent: { first_response: "1" } } } }
    assert_nil AppSetting.current.sla_minutes("urgent", "first_response")
  end

  test "staff see both lines on the ticket page and the badge in the queue" do
    targets!
    urgent!
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#properties dl.sla dt", 2
    assert_select "#properties .sla__state--overdue", /overdue by 2 h/
    assert_select "#properties .sla__state--overdue svg"
    assert_select "#properties .sla__state--running", /due in 5 h/

    get tickets_url(view: "all")
    assert_select "##{ActionView::RecordIdentifier.dom_id(@ticket)} a.ticket-link .sla-badge--overdue[title=?] svg[aria-label=?]",
                  "First response: overdue by 2 h", "Overdue. First response: overdue by 2 h"

    urgent!(created: 7.hours.ago, first_response_at: 7.hours.ago + 20.minutes)
    get ticket_url(@ticket)
    assert_select "#properties .sla__state--met", /answered in 20 min/
    assert_select "#properties .sla__state--soon", /due in 1 h/
    get tickets_url(view: "all")
    assert_select "##{ActionView::RecordIdentifier.dom_id(@ticket)} .sla-badge--soon svg[aria-label^='Due soon. Resolution']"

    @ticket.update_columns(status: "pending")
    get ticket_url(@ticket)
    assert_select "#properties .sla__state--waiting", /waiting for the customer/
    get tickets_url(view: "all")
    assert_select "##{ActionView::RecordIdentifier.dom_id(@ticket)} .sla-badge", 0
  end

  test "nothing shows without targets, to requesters, or on the shared page" do
    urgent!
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "dl.sla", 0
    get tickets_url(view: "all")
    assert_select ".sla-badge", 0

    targets!
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "dl.sla", 0
    assert_not_includes response.body, "overdue"
    get tickets_url
    assert_select ".sla-badge", 0

    @ticket.share!(actor: users(:agent))
    sign_out :user
    get shared_ticket_url(@ticket.share_token)
    assert_select "dl.sla", 0
    assert_not_includes response.body, "overdue"
  end

  test "the lines are translated" do
    targets!
    urgent!
    sign_in users(:agent)
    get ticket_url(@ticket), headers: { "Accept-Language" => "bg" }
    assert_select "#properties dl.sla dt", "Първи отговор"
    assert_select "#properties .sla__state--overdue", /просрочено с 2 ч/
  end
end
