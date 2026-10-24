require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "only staff write internal notes" do
    comment = Comment.new(ticket: tickets(:printer), author: users(:anna), body: "psst", internal: true)
    assert comment.invalid?
    assert comment.errors.of_kind?(:internal, :staff_only)
  end

  test "a comment writes a replied or noted event" do
    ticket = tickets(:printer)
    reply = ticket.add_comment(author: users(:anna), body: "Thanks!")
    note = ticket.add_comment(author: users(:agent), body: "Call her back", internal: true)
    assert_equal [ "replied", false ], [ reply.event.action, reply.event.internal ]
    assert_equal [ "noted", true ], [ note.event.action, note.event.internal ]
  end

  test "a comment touches its ticket" do
    ticket = tickets(:printer)
    before = ticket.updated_at
    ticket.add_comment(author: users(:anna), body: "Thanks!")
    assert_operator ticket.reload.updated_at, :>, before
  end

  test "comments are immutable" do
    assert_raises(ActiveRecord::ReadOnlyRecord) { comments(:printer_reply).update!(body: "changed") }
    begin
      comments(:printer_reply).destroy
    rescue ActiveRecord::ReadOnlyRecord
      nil
    end
    assert Comment.exists?(comments(:printer_reply).id)
  end

  test "visible_to hides internal notes from requesters" do
    assert_includes Comment.visible_to(users(:agent)), comments(:printer_note)
    assert_not_includes Comment.visible_to(users(:anna)), comments(:printer_note)
    assert_includes Comment.visible_to(users(:anna)), comments(:printer_reply)
  end

  test "files can be attached to a new comment" do
    comment = tickets(:printer).add_comment(author: users(:anna), body: "Photo attached", files: [ upload ])
    assert comment.persisted?
    assert_equal "hello.txt", comment.reload.files.first.filename.to_s
  end
end
