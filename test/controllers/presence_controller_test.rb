require "test_helper"

# What staff see of who is online (specs/presence.md).
class PresenceControllerTest < ActionDispatch::IntegrationTest
  setup { Presence.reset }
  teardown { Presence.reset }

  test "requesters may not ask and see no presence button" do
    sign_in users(:anna)
    get presence_url
    assert_response :forbidden
    get tickets_url
    assert_select "#presence", count: 0
    assert_select "turbo-cable-stream-source[channel=PresenceChannel]"
  end

  test "staff see the staff online by name, requesters as a number, and the other viewers of a ticket" do
    Presence.join("1", users(:agent_two), tickets(:printer))
    Presence.join("2", users(:anna), tickets(:printer))
    Presence.join("3", users(:carl))
    Presence.join("4", users(:agent), tickets(:printer))
    sign_in users(:agent)

    get presence_url(ticket: tickets(:printer).number), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_select "turbo-stream[action=replace][target=presence-button] template summary[aria-label=?]", "4 people online now"
    assert_select "turbo-stream[target=presence-list] template" do
      assert_select "li", 2
      assert_select "li:first-child .presence__you", "you"
      assert_select "li", text: /#{users(:agent_two).display_name}/
      assert_select ".presence__requesters", "and 2 requesters"
    end
    assert_select "turbo-stream[target=ticket-viewers] template p.ticket-viewers:not([hidden])" do
      assert_select ".ticket-viewers__person", 2
      assert_select ".ticket-viewers__person", text: /#{users(:agent).display_name}/, count: 0
      assert_select ".ticket-viewers__role", "(Requester)"
    end
  end

  test "an agent counts only requesters of their organizations" do
    memberships(:agent_two_globex).destroy
    Presence.join("1", users(:anna))
    Presence.join("2", users(:carl))
    sign_in users(:agent_two)
    get presence_url, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_select ".presence__requesters", "and 1 requester"
    assert_select "turbo-stream[target=ticket-viewers]", count: 0
  end

  test "a hidden ticket gives no viewers line; alone on a ticket the line is hidden" do
    sign_in users(:agent)
    get presence_url(ticket: 99_999), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_select "turbo-stream[target=ticket-viewers]", count: 0

    get ticket_url(tickets(:printer))
    assert_select "#presence[data-dropdown] #presence-button[aria-label=?]", "1 person online now"
    assert_select ".ticket-main #ticket-viewers[hidden]"
    assert_select "[data-ticket-page][data-ticket=?]", tickets(:printer).number.to_s
    assert_select "turbo-cable-stream-source[channel=PresenceChannel][data-ticket=?]", tickets(:printer).number.to_s
  end
end
