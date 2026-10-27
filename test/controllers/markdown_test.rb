require "test_helper"

# Markdown per message (specs/markdown.md).
class MarkdownTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    ActionMailer::Base.deliveries.clear
  end

  test "a reply and a new ticket can be written as Markdown" do
    sign_in users(:anna)
    post ticket_comments_url(@ticket), params: { comment: { body: "**Still** blank", markdown: "1" } }
    assert Comment.order(:id).last.markdown?
    post tickets_url, params: { ticket: { subject: "Formatted", description: "- one\n- two", markdown: "1",
                                          organization_id: organizations(:acme).id } }
    assert Ticket.order(:id).last.markdown?

    get ticket_url(Ticket.order(:id).last)
    assert_select "#description .ticket-text.markdown-body[data-message-text] ul li", 2
    assert_select "#description button.markdown-box[aria-pressed=true]"
    assert_select "form.composer__form input[type=checkbox][name='comment[markdown]']"
  end

  test "plain messages keep their paragraphs" do
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "#description .ticket-text:not(.markdown-body) p.ticket-text__p"
    assert_select "#description button.markdown-box[aria-pressed=false]"
  end

  test "the switch follows edit rights and is not an edit" do
    reply = @ticket.add_comment(author: users(:agent), body: "**Try** this")
    sign_in users(:anna)
    patch markdown_ticket_comment_url(@ticket, reply), params: { markdown: "1" }
    assert_response :forbidden
    get ticket_url(@ticket)
    assert_select "#event-#{reply.event.id} button.markdown-box", 0

    patch markdown_ticket_description_url(@ticket), params: { markdown: "1" }
    assert_redirected_to ticket_url(@ticket, anchor: "description")
    assert @ticket.reload.markdown?
    assert_not @ticket.edited?
    assert_empty @ticket.revisions

    sign_in users(:agent)
    patch markdown_ticket_comment_url(@ticket, reply), params: { markdown: "1" }
    assert_redirected_to ticket_url(@ticket, anchor: "event-#{reply.event.id}")
    assert reply.reload.markdown?
    assert_not reply.edited?

    # Turbo drops a redirect's anchor; its requests get the bare page.
    patch markdown_ticket_comment_url(@ticket, reply), params: { markdown: "0" }, headers: { "X-Turbo-Request-Id" => "r1" }
    assert_redirected_to ticket_url(@ticket)
    patch markdown_ticket_comment_url(@ticket, reply), params: { markdown: "1" }
    get ticket_url(@ticket)
    assert_select "#event-#{reply.event.id} .markdown-body strong", "Try"
  end

  test "shared pages and the HTML email render Markdown; the text email stays plain" do
    @ticket.update_columns(markdown: true)
    @ticket.share!(actor: users(:agent), password: nil)
    get shared_ticket_url(@ticket.share_token)
    assert_select ".markdown-body"
    assert_select "button.markdown-box", 0

    perform_enqueued_jobs do
      @ticket.add_comment(author: users(:agent), body: "Use **the spare** roll", markdown: true)
    end
    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ users(:anna).email ] }
    assert_includes mail.html_part.body.to_s, "<strong>the spare</strong>"
    assert_includes mail.text_part.body.to_s, "Use **the spare** roll"
  end
end
