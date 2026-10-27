require "test_helper"

# Clickable Markdown task lists (specs/markdown.md "Task lists").
class TaskListTest < ActionDispatch::IntegrationTest
  TEXT = "Steps:\n\n- [ ] cable\n- [x] driver\n\n```\n- [ ] not a task\n```\n\n> 1. [ ] quoted".freeze

  setup do
    @ticket = tickets(:printer)
    @reply = @ticket.add_comment(author: users(:anna), body: TEXT, markdown: true)
  end

  test "editors get task lines; others, shared pages and code blocks do not" do
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} [data-task-path=?]", task_ticket_comment_path(@ticket, @reply) do
      assert_select "input[type=checkbox][disabled][data-task-line]", 3
      assert_select "input[data-task-line='3']"
    end
    assert_select "[data-sourcepos]", 0

    staff_reply = @ticket.add_comment(author: users(:agent), body: "- [ ] for you", markdown: true)
    get ticket_url(@ticket)
    assert_select "#event-#{staff_reply.event.id} input[type=checkbox][disabled]"
    assert_select "#event-#{staff_reply.event.id} input[data-task-line]", 0

    @ticket.share!(actor: users(:agent), password: nil)
    get shared_ticket_url(@ticket.share_token)
    assert_select "input[data-task-line], [data-task-path]", 0
  end

  test "a click flips only that line and is an edit" do
    sign_in users(:anna)
    patch task_ticket_comment_url(@ticket, @reply), params: { line: 3, checked: "1" }
    assert_response :no_content
    assert_equal TEXT.sub("- [ ] cable", "- [x] cable"), @reply.reload.body
    assert @reply.edited?

    patch task_ticket_comment_url(@ticket, @reply), params: { line: 10, checked: "1" }
    assert_includes @reply.reload.body, "> 1. [x] quoted"

    patch task_ticket_comment_url(@ticket, @reply), params: { line: 7, checked: "1" }
    assert_response :unprocessable_content
    patch task_ticket_comment_url(@ticket, @reply), params: { line: 99, checked: "1" }
    assert_response :unprocessable_content
    assert_includes @reply.reload.body, "- [ ] not a task"
  end

  test "clicks by one person within 10 minutes form one earlier version" do
    sign_in users(:anna)
    patch task_ticket_comment_url(@ticket, @reply), params: { line: 3, checked: "1" }
    patch task_ticket_comment_url(@ticket, @reply), params: { line: 4, checked: "0" }
    assert_equal 1, @reply.revisions.count
    assert_equal TEXT, @reply.revisions.first.body

    travel 11.minutes do
      patch task_ticket_comment_url(@ticket, @reply), params: { line: 3, checked: "0" }
    end
    assert_equal 2, @reply.revisions.count
  end

  test "the request's tasks; no rights, no ticks" do
    @ticket.update_columns(description: "- [ ] one", markdown: true)
    sign_in users(:boris)
    patch task_ticket_description_url(@ticket), params: { line: 1, checked: "1" }
    assert_response :forbidden
    sign_in users(:carl)
    patch task_ticket_description_url(@ticket), params: { line: 1, checked: "1" }
    assert_response :not_found

    sign_in users(:agent)
    patch task_ticket_description_url(@ticket), params: { line: 1, checked: "1" }
    assert_response :no_content
    assert_equal "- [x] one", @ticket.reload.description

    staff_reply = @ticket.add_comment(author: users(:agent), body: "- [ ] for you", markdown: true)
    sign_in users(:anna)
    patch task_ticket_comment_url(@ticket, staff_reply), params: { line: 1, checked: "1" }
    assert_response :forbidden
  end
end
