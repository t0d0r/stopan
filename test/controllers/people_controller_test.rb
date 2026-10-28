require "test_helper"

# A person's profile with statistics, and the requester filter (specs/people.md).
class PeopleControllerTest < ActionDispatch::IntegrationTest
  test "staff open the requester's profile from the ticket page" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select "#requester-title ~ dl a[href=?]", person_path(users(:anna)), users(:anna).display_name
    assert_select "#requester-title ~ dl button.copy-value[type=button][data-copy-value=?] .copy-value__text", users(:anna).email, users(:anna).email
    assert_select "#requester-title ~ dl button.copy-value[title=?]", users(:anna).email
    assert_select "#requester-title ~ dl a[href^=mailto]", 0

    get person_url(users(:anna))
    assert_response :success
    assert_select "h1.desk__title", users(:anna).display_name
    # The email copies itself instead of opening the mail program (specs/ui.md).
    assert_select ".person-head button.copy-value[data-copy-value=?]", users(:anna).email
    assert_select "a[href^=mailto]", 0
    assert_select ".report-tile", 6
    tiles = css_select(".report-tile").to_h { |tile| [ tile.at_css(".report-tile__label").text, tile.at_css(".report-tile__value").text ] }
    assert_equal "2", tiles["Tickets"]
    assert_equal "1", tiles["Unsolved now"]
    assert_equal "1", tiles["Done"]
    assert_select ".person-panel a[href=?]", ticket_path(tickets(:printer))
    assert_select "a[href=?]", tickets_path(view: "all", requester: users(:anna).id), "All 2 tickets from this person"
  end

  test "the queue filters by requester, shows a removable chip and keeps it in the forms" do
    sign_in users(:agent)
    get tickets_url(view: "all", requester: users(:anna).id)
    assert_equal %w[#1001 #1004], css_select("td.ticket-number").map { |cell| cell.text.strip }.sort
    assert_select ".chip", /Requester: #{users(:anna).display_name}/
    assert_select ".chip a.chip__remove[href=?]", tickets_path + "?view=all"
    assert_select "form.filters input[type=hidden][name=requester][value=?]", users(:anna).id.to_s
    assert_select "#bulk-form input[name='list[requester]'][value=?]", users(:anna).id.to_s
  end

  test "agents only reach people of their organizations; requesters none; the API the same" do
    outsider = User.create!(name: "Out Side", email: "out@example.com", password: "s3cret-pass-1", role: "requester")
    sign_in users(:agent)
    get person_url(outsider)
    assert_response :not_found
    sign_in users(:admin)
    get person_url(outsider)
    assert_response :success
    assert_select ".panel__empty", /No tickets/

    sign_in users(:anna)
    get person_url(users(:boris))
    assert_response :forbidden

    token = users(:agent).api_tokens.create!(name: "t").plain_token
    get api_v1_person_url(users(:anna)), headers: { "Authorization" => "Bearer #{token}" }
    assert_equal 2, response.parsed_body.dig("stats", "total")
    get api_v1_person_url(outsider), headers: { "Authorization" => "Bearer #{token}" }
    assert_response :not_found
  end
end
