require "test_helper"

# Word diffs and restoring earlier versions (specs/timeline.md "Editing").
class RevisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @reply = @ticket.add_comment(author: users(:anna), body: "The printer prints blank pages.")
    @reply.edit(editor: users(:agent), body: "The printer prints empty pages.")
  end

  test "staff see what each edit changed and a restore button" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} .revisions__item" do
      assert_select ".revision-diff del", "blank"
      assert_select ".revision-diff ins", "empty"
      assert_select "form[action=?] button", restore_ticket_revision_path(@ticket, @reply.revisions.first), "Restore this version"
    end
  end

  test "a changed subject is shown as a diff; an entry equal to the current text has no button" do
    @ticket.edit(editor: users(:agent), subject: "Printer broken", description: @ticket.description)
    @reply.edit(editor: users(:agent), body: "The printer prints blank pages.")
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#description .revisions__subject del", /Receipt/
    assert_equal "Printerbroken", css_select("#description .revisions__subject ins").map(&:text).join
    # The oldest version of the reply is the current text again.
    assert_select "#event-#{@reply.event.id} .revisions__same", "Same as the current text"
  end

  test "staff restore an earlier version as an ordinary edit" do
    sign_in users(:agent_two)
    assert_difference -> { @reply.revisions.count }, 1 do
      post restore_ticket_revision_url(@ticket, @reply.revisions.first)
    end
    assert_redirected_to ticket_url(@ticket, anchor: "event-#{@reply.event.id}")
    assert_equal "Earlier version restored.", flash[:notice]
    assert_equal "The printer prints blank pages.", @reply.reload.body
    assert_equal users(:agent_two), @reply.edited_by
    assert_equal "The printer prints empty pages.", @reply.revisions.first.body

    old = [ @ticket.subject, @ticket.description ]
    @ticket.edit(editor: users(:agent), subject: "Broken", description: "Gone")
    post restore_ticket_revision_url(@ticket, @ticket.revisions.first)
    assert_redirected_to ticket_url(@ticket, anchor: "description")
    assert_equal old, [ @ticket.reload.subject, @ticket.description ]
  end

  test "requesters cannot restore; revisions of other tickets are not found" do
    sign_in users(:anna)
    post restore_ticket_revision_url(@ticket, @reply.revisions.first)
    assert_response :forbidden
    get ticket_url(@ticket)
    assert_select ".revisions", 0

    sign_in users(:agent)
    post restore_ticket_revision_url(tickets(:vpn), @reply.revisions.first)
    assert_response :not_found
  end
end
