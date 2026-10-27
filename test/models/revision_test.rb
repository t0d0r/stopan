require "test_helper"

# Editing text keeps the earlier version (specs/timeline.md "Editing").
class RevisionTest < ActiveSupport::TestCase
  setup do
    @ticket = tickets(:printer)
    @reply = @ticket.add_comment(author: users(:anna), body: "My pasword is hunter2")
  end

  test "editing a comment keeps the previous text and is not activity" do
    ticket_time = @ticket.reload.updated_at
    comment_time = @reply.updated_at

    assert_no_difference -> { TicketEvent.count } do
      assert @reply.edit(editor: users(:agent), body: "  My password is [removed]  ")
    end

    @reply.reload
    assert_equal "My password is [removed]", @reply.body
    assert_equal users(:agent), @reply.edited_by
    assert @reply.edited?
    assert_equal comment_time, @reply.updated_at
    assert_equal ticket_time, @ticket.reload.updated_at

    revision = @reply.revisions.sole
    assert_equal "My pasword is hunter2", revision.body
    assert_equal users(:agent), revision.editor
    assert_nil revision.subject
    assert revision.readonly?
  end

  test "unchanged text records nothing; invalid text saves nothing" do
    assert @reply.edit(editor: users(:anna), body: "My pasword is hunter2 ")
    assert_not @reply.reload.edited?

    assert_not @reply.edit(editor: users(:anna), body: " ")
    assert @reply.errors[:body].any?
    assert_equal "My pasword is hunter2", @reply.reload.body
    assert_empty @reply.revisions
  end

  test "line ends from a browser form do not count as a change" do
    assert @reply.edit(editor: users(:anna), body: "My pasword is hunter2")
    reply = @ticket.add_comment(author: users(:anna), body: "One\r\ntwo")
    assert_equal "One\ntwo", reply.body
    assert reply.edit(editor: users(:anna), body: "One\r\ntwo")
    assert_not reply.reload.edited?
    assert_equal [ [ :same, "a\nb" ] ], TextDiff.diff("a\nb", "a\r\nb")
  end

  test "a comment stays read-only outside an edit" do
    @reply.edit(editor: users(:anna), body: "Changed")
    assert_raises(ActiveRecord::ReadOnlyRecord) { @reply.update!(body: "Sneaky") }
  end

  test "editing the request keeps subject and description" do
    old_subject = @ticket.subject
    old_description = @ticket.description
    time = @ticket.updated_at

    assert @ticket.edit(editor: users(:anna), subject: "Printer prints blank pages", description: "Still blank.")
    @ticket.reload
    assert_equal [ "Printer prints blank pages", "Still blank." ], [ @ticket.subject, @ticket.description ]
    assert_equal users(:anna), @ticket.edited_by
    assert_equal time, @ticket.updated_at
    assert_equal [ old_subject, old_description ], [ @ticket.revisions.sole.subject, @ticket.revisions.sole.body ]

    assert_not @ticket.edit(editor: users(:anna), subject: "x" * 201, description: "Still blank.")
    assert_equal 1, @ticket.revisions.count
  end

  test "earlier versions are listed newest first and keep their editors in history" do
    @reply.edit(editor: users(:anna), body: "Second")
    @reply.edit(editor: users(:agent_two), body: "Third")
    assert_equal [ "Second", "My pasword is hunter2" ], @reply.revisions.reload.map(&:body)
    assert users(:agent_two).ticket_history?
    assert_includes User.ids_with_ticket_history([ users(:agent_two).id ]), users(:agent_two).id
  end
end
