require "test_helper"

# Markup for the phone layout of the menu bar and the ticket page (ui.md
# "Ticket page on phones"); application.css and application.js do the rest.
class TicketPhoneLayoutTest < ActionDispatch::IntegrationTest
  test "the menu bar has a menu button and a stylesheet for pages without JavaScript" do
    sign_in users(:agent)
    get tickets_url
    assert_select ".menubar__right button.menubar__burger[aria-label=Menu][aria-expanded=false][data-menu-toggle]"
    assert_select ".menubar__right details.account-menu[data-dropdown]" do
      assert_select "summary.menubar__user .menubar__user-name", users(:agent).display_name
      assert_select ".account-menu__panel a.account-menu__item[href=?]", edit_user_registration_path, "Your account"
      assert_select ".account-menu__panel form.menubar__logout button.account-menu__item", "Logout"
    end
    assert_match %r{<noscript><link rel="stylesheet" href="/assets/noscript-\h+\.css"}, response.body
    assert_select "body.ticket-view", count: 0
  end

  test "the ticket page has closed panels, a hidden search and a Reply bar on phones" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select "body.ticket-view .menubar__search"
    { "properties" => "Properties", "requester" => "Requester", "sharing" => "Sharing" }.each do |id, title|
      assert_select "section##{id}.side-panel[data-side-panel]:not(.is-open)" do
        assert_select ".sticky__bar .side-panel__caption", title
        assert_select ".sticky__bar button.side-panel__toggle[aria-expanded=false][aria-controls=?]", "#{id}-body", title
        assert_select ".panel__body##{id}-body"
      end
    end
    assert_select "[data-ticket-page] > .reply-bar button[data-reply-open][aria-controls=composer]", "Reply"
    assert_select "#composer.composer:not(.is-open) button.composer__close[data-reply-close][aria-label=Close]"
  end

  test "a reply with errors and a properties update with errors start open" do
    sign_in users(:anna)
    post ticket_comments_url(tickets(:printer)), params: { comment: { body: " " } }
    assert_response :unprocessable_content
    assert_select "#composer.is-open"

    sign_in users(:agent)
    patch ticket_url(tickets(:old_question)), params: { ticket: { status: "pending" } }
    assert_response :unprocessable_content
    assert_select "section#properties.is-open .form-errors"
  end

  test "without the composer there is no Reply bar" do
    sign_in users(:admin)
    ticket = tickets(:printer)
    ticket.update_columns(deleted_at: Time.current, deleted_by_id: users(:admin).id)
    get ticket_url(ticket)
    assert_response :success
    assert_select "#composer", count: 0
    assert_select ".reply-bar", count: 0
  end
end
