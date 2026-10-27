require "test_helper"

# Order of the timeline and the long request (specs/timeline.md).
class TimelineOrderTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @ticket.add_comment(author: users(:agent), body: "Newest reply")
  end

  def event_ids
    css_select("ol.timeline > li").map { |item| item["id"] }
  end

  def composer_before_timeline?
    html = response.body
    html.index("composer__form") < html.index('class="timeline')
  end

  test "oldest first by default, with the reply box under the timeline" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "ol.timeline > li:last-child", /Newest reply/
    assert_not composer_before_timeline?
    assert_select "#description[data-long-request][data-more='Show the whole request'][data-less='Collapse the request']"
  end

  test "an administrator sets newest first for everyone; a browser may choose its own" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    oldest_first = event_ids

    sign_in users(:admin)
    get admin_settings_url
    assert_select "#timeline-order select[name='app_setting[timeline_order]'] option[selected][value=oldest_first]", "Oldest first"
    patch admin_settings_url, params: { app_setting: { timeline_order: "newest_first" } }
    assert_equal "newest_first", AppSetting.current.reload.timeline_order
    patch admin_settings_url, params: { app_setting: { timeline_order: "sideways" } }
    assert_response :unprocessable_content

    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_equal oldest_first.reverse, event_ids
    assert_select "ol.timeline > li:first-child", /Newest reply/
    assert composer_before_timeline?

    get edit_user_registration_url
    assert_select "form#timeline-order select[name=timeline_order] option[selected][value=default]", "Site default (Newest first)"
    patch preferences_url, params: { timeline_order: "oldest_first" }
    get ticket_url(@ticket)
    assert_select "ol.timeline > li:last-child", /Newest reply/
    assert_not composer_before_timeline?
    get edit_user_registration_url
    assert_select "form#timeline-order option[selected][value=oldest_first]"

    patch preferences_url, params: { timeline_order: "default" }
    get ticket_url(@ticket)
    assert_select "ol.timeline > li:first-child", /Newest reply/
  end

  test "the shared page follows the order too" do
    AppSetting.current.update!(timeline_order: "newest_first")
    @ticket.share!(actor: users(:agent))
    get shared_ticket_url(@ticket.share_token)
    assert_select "ol.timeline > li:first-child", /Newest reply/
    assert_select "#description[data-long-request]"
  end
end
