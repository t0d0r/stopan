require "test_helper"
require "turbo/broadcastable/test_helper"

# Editing the request and replies per role (specs/timeline.md "Editing").
class EditsControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    @ticket = tickets(:printer)
    @own_reply = @ticket.add_comment(author: users(:anna), body: "It still prints blank pages.")
    @staff_reply = @ticket.add_comment(author: users(:agent), body: "Please send a photo.")
    @note = @ticket.add_comment(author: users(:agent), body: "STAFF-ONLY check the spare", internal: true)
  end

  test "the requester edits their own request and own reply" do
    sign_in users(:anna)
    patch ticket_description_url(@ticket), params: { ticket: { subject: "Printer blank", description: "Blank pages." } }
    assert_redirected_to ticket_url(@ticket, anchor: "description")
    assert_equal "Request updated.", flash[:notice]
    assert_equal "Printer blank", @ticket.reload.subject

    patch ticket_comment_url(@ticket, @own_reply), params: { comment: { body: "Fixed typo." } }
    assert_redirected_to ticket_url(@ticket, anchor: "event-#{@own_reply.event.id}")
    assert_equal "Reply updated.", flash[:notice]
    assert_equal "Fixed typo.", @own_reply.reload.body
  end

  test "the requester cannot edit staff replies, internal notes, closed or other tickets" do
    sign_in users(:anna)
    get edit_ticket_comment_url(@ticket, @staff_reply)
    assert_response :forbidden
    patch ticket_comment_url(@ticket, @staff_reply), params: { comment: { body: "Hacked" } }
    assert_response :forbidden
    patch ticket_comment_url(@ticket, @note), params: { comment: { body: "Hacked" } }
    assert_response :not_found

    closed = tickets(:old_question)
    get edit_ticket_description_url(closed)
    assert_response :forbidden

    sign_in users(:boris)
    patch ticket_description_url(@ticket), params: { ticket: { subject: "Hacked", description: "Hacked" } }
    assert_response :not_found
    assert_equal "Please send a photo.", @staff_reply.reload.body
  end

  test "staff edit any reply, note and request, also on closed tickets" do
    sign_in users(:agent_two)
    patch ticket_comment_url(@ticket, @own_reply), params: { comment: { body: "Password [removed]" } }
    assert_equal "Password [removed]", @own_reply.reload.body
    patch ticket_comment_url(@ticket, @note), params: { comment: { body: "Spare is in room 2" } }
    assert_equal "Internal note updated.", flash[:notice]
    patch ticket_description_url(tickets(:old_question)), params: { ticket: { subject: "Holiday hours", description: "Open on the 24th?" } }
    assert_equal "Holiday hours", tickets(:old_question).reload.subject
  end

  test "edit pages render the form inside the frame; invalid text is 422" do
    sign_in users(:anna)
    get edit_ticket_comment_url(@ticket, @own_reply)
    assert_response :success
    assert_select "turbo-frame#text_comment_#{@own_reply.id} form[data-turbo-frame=_top] textarea[name='comment[body]']"
    get edit_ticket_description_url(@ticket)
    assert_select "turbo-frame#description-text form input[name='ticket[subject]']"

    patch ticket_comment_url(@ticket, @own_reply), params: { comment: { body: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors"
  end

  test "the ticket page shows edit links, the edited marker, and earlier versions to staff only" do
    @own_reply.edit(editor: users(:agent), body: "Password [removed]")
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "a.edit-link[href=?]", edit_ticket_description_path(@ticket)
    assert_select "a.edit-link[href=?][data-turbo-frame=?]", edit_ticket_comment_path(@ticket, @own_reply), "text_comment_#{@own_reply.id}"
    assert_select "a.edit-link[href=?]", edit_ticket_comment_path(@ticket, @staff_reply), 0
    assert_select "#event-#{@own_reply.event.id} .message__bar .edited-tag", /edited by Maria Agent/
    assert_select "#description .message__bar" do
      assert_select ".message__kind", "Original request"
      assert_select ".message__author", users(:anna).display_name
      assert_select ".role-tag"
      assert_select "time"
      assert_select ".message__boxes a.edit-link[aria-label=Edit][title=?]", "Edit (or double-click the text)"
    end
    assert_select ".message__body .message__author", 0
    assert_select ".revisions", 0
    assert_not_includes response.body, "It still prints blank pages."

    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#event-#{@own_reply.event.id} .revisions summary", "1 earlier version"
    assert_select "#event-#{@own_reply.event.id} .revisions__item", /Before the edit by Maria Agent.*It still prints blank pages\./m
  end

  test "the shared page shows the current text and the marker, never earlier versions" do
    @own_reply.edit(editor: users(:agent), body: "Password [removed]")
    @ticket.share!(actor: users(:agent), password: nil)
    get shared_ticket_url(@ticket.share_token)
    assert_select ".edited-tag", /edited by Maria Agent/
    assert_select ".edit-link, .revisions", 0
    assert_not_includes response.body, "It still prints blank pages."
  end

  test "editing a note signals staff pages only; a reply also the requester and shared pages" do
    @ticket.share!(actor: users(:agent), password: nil)
    sign_in users(:agent)
    streams = { staff: [ @ticket, :page, :staff ], public: [ @ticket, :page, :public ], share: @ticket.share_stream }
    capture = lambda do |&block|
      result = {}
      perform_enqueued_jobs do
        result[:staff] = capture_turbo_stream_broadcasts(streams[:staff]) do
          result[:public] = capture_turbo_stream_broadcasts(streams[:public]) do
            result[:share] = capture_turbo_stream_broadcasts(streams[:share], &block)
          end
        end
      end
      result.transform_values(&:size)
    end

    counts = capture.call { patch ticket_comment_url(@ticket, @note), params: { comment: { body: "Room 2" } } }
    assert_equal({ staff: 1, public: 0, share: 0 }, counts)

    counts = capture.call { patch ticket_comment_url(@ticket, @staff_reply), params: { comment: { body: "A photo, please." } } }
    assert_equal({ staff: 1, public: 1, share: 1 }, counts)
  end
end
