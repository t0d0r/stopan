require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  test "a requester replies to their ticket" do
    sign_in users(:carl)
    assert_difference "Comment.count" do
      post ticket_comments_url(tickets(:vpn)), params: { comment: { body: "Still dropping.", files: [ upload ] } }
    end
    comment = Comment.last
    assert_redirected_to ticket_url(tickets(:vpn), anchor: "event-#{comment.event.id}")
    assert_not comment.internal?
    assert comment.files.attached?
    assert_equal "open", tickets(:vpn).reload.status
  end

  test "a requester's internal flag and status are ignored" do
    sign_in users(:anna)
    post ticket_comments_url(tickets(:printer)), params: { comment: { body: "Hello", internal: "1", status: "closed" } }
    comment = Comment.last
    assert_not comment.internal?
    assert_equal "open", tickets(:printer).reload.status
  end

  test "a requester cannot comment on tickets they cannot see" do
    sign_in users(:boris)
    assert_no_difference "Comment.count" do
      post ticket_comments_url(tickets(:printer)), params: { comment: { body: "Me too" } }
    end
    assert_response :not_found
  end

  test "nobody replies publicly to a closed ticket" do
    sign_in users(:anna)
    post ticket_comments_url(tickets(:old_question)), params: { comment: { body: "One more thing" } }
    assert_response :forbidden

    sign_in users(:agent)
    post ticket_comments_url(tickets(:old_question)), params: { comment: { body: "Hi", internal: "0" } }
    assert_response :forbidden
  end

  test "staff add internal notes, also on closed tickets" do
    sign_in users(:agent)
    post ticket_comments_url(tickets(:old_question)), params: { comment: { body: "Customer called again", internal: "1" } }
    assert Comment.last.internal?
    assert_equal "noted", Comment.last.event.action
    follow_redirect!
    assert_select ".flash", /Internal note added/
  end

  test "staff reply and set the status in one go" do
    sign_in users(:agent)
    post ticket_comments_url(tickets(:email_account)), params: { comment: { body: "Account created.", internal: "0",
                                                                             status: "resolved" } }
    assert_equal "resolved", tickets(:email_account).reload.status
  end

  test "an empty reply re-renders the ticket with errors" do
    sign_in users(:anna)
    assert_no_difference "Comment.count" do
      post ticket_comments_url(tickets(:printer)), params: { comment: { body: " " } }
    end
    assert_response :unprocessable_content
    assert_select ".composer .form-errors"
  end

  test "a disallowed file type is refused" do
    sign_in users(:anna)
    assert_no_difference "Comment.count" do
      post ticket_comments_url(tickets(:printer)), params: { comment: { body: "see file",
                                                                         files: [ upload("page.html", "text/html") ] } }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /page.html is not an allowed file type/
  end
end
