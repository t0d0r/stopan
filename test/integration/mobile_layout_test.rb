require "test_helper"

# Markup behind the phone rules (specs/mobile.md): stacked lists, the
# columns that give way, and no hover-only content. The sizes themselves
# are checked in a browser sweep (mobile.md "Checks").
class MobileLayoutTest < ActionDispatch::IntegrationTest
  test "the shared links on the dashboard are stacked rows, not a table" do
    ticket = tickets(:printer)
    ticket.share!(actor: users(:admin), password: "secret123")
    sign_in users(:admin)
    get admin_root_url
    assert_select "ul.share-list li.share-list__item##{dom_id(ticket, :shared)}" do
      assert_select ".share-list__title .ticket-number", ticket.reference
      assert_select ".share-list__title a[href=?]", ticket_path(ticket, anchor: "sharing"), ticket.subject
      assert_select ".share-list__meta", /With password|password/i
      assert_select "form.share-list__action button", /Stop sharing/
    end
    assert_select "table.table-shared", 0
  end

  test "ticket links carry no hover tooltip" do
    sign_in users(:agent)
    get tickets_url
    assert_select "a.ticket-link"
    assert_select "a.ticket-link[title]", 0
    sign_in users(:anna)
    get tickets_url(view: "organization")
    assert_select "a.ticket-link[title]", 0
  end

  test "the admin users list shows email and role under the name for phones" do
    sign_in users(:admin)
    get admin_users_url
    anna = users(:anna)
    assert_select "##{dom_id(anna)} td:first-child .only-narrow.user-cell__email", anna.email
    assert_select "##{dom_id(anna)} td:first-child .only-narrow .role-pill", "Requester"
    assert_select "##{dom_id(anna)} td.hide-narrow", minimum: 4
  end
end
