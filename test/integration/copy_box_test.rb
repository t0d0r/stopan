require "test_helper"

# Copy box on every message (specs/ui.md "Copy box").
class CopyBoxTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @ticket.add_comment(author: users(:agent), body: "Please send a photo.")
    @ticket.add_comment(author: users(:agent), body: "STAFF-ONLY spare", internal: true)
  end

  test "the request, replies and notes each have a hidden copy box next to their text" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    messages = 1 + @ticket.events.where.not(comment_id: nil).count
    assert_select ".message", messages
    assert_select ".message .sticky__bar button.copy-box[hidden][data-copy-message][aria-label='Copy text']", messages
    assert_select ".message [data-message-text]", messages
  end

  test "requesters and shared pages copy only what they see" do
    public_messages = 1 + @ticket.events.where.not(comment_id: nil).where(internal: false).count
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "button.copy-box", public_messages
    assert_not_includes response.body, "STAFF-ONLY spare"

    @ticket.share!(actor: users(:agent), password: nil)
    get shared_ticket_url(@ticket.share_token)
    assert_select "button.copy-box", public_messages
    assert_select "[data-message-text]", public_messages
  end
end
