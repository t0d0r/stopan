require "test_helper"

# Replies by mail keep their HTML, and inline images come from the
# message's own files (specs/organization-mail.md "Replies and inline
# images").
class ReplyMailViewTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  setup do
    @org = organizations(:acme)
    @org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk",
                 mailbox_address: "support@acme.example")
    @ticket = tickets(:printer)
  end

  # A multipart mail with text, HTML and one inline image big enough to be kept.
  def mail_with_image(subject:, html:, cid: "pic1@mail", type: "image/png", filename: "photo.png", data: PNG + ("\0" * 11_000))
    mail = Mail.new
    mail.from = users(:anna).email
    mail.to = "support@acme.example"
    mail.subject = subject
    mail.text_part = Mail::Part.new { body "Here is the photo." }
    mail.html_part = Mail::Part.new do
      content_type "text/html; charset=UTF-8"
      body html
    end
    mail.attachments.inline[filename] = { mime_type: type, content: data }
    mail.attachments.inline[filename].content_id = "<#{cid}>"
    mail.to_s
  end

  def reply_html
    %(<p>Here is the <b>photo</b>.</p><img src="cid:pic1@mail" alt="Photo"><img src="cid:missing@mail" alt="Gone">) +
      %(<script>alert(1)</script><blockquote>earlier message</blockquote>)
  end

  def process_reply(**options)
    raw = mail_with_image(subject: "Re: [Stopan ##{@ticket.number}] Reply: printer", html: reply_html, **options)
    assert_equal :reply, MailboxMessage.new(@org, raw).process
    @ticket.comments.order(:id).last
  end

  test "a reply by mail keeps its cleaned HTML and its inline image's content id" do
    comment = process_reply
    assert_equal "Here is the photo.", comment.body
    assert_includes comment.mail_html, "<b>photo</b>"
    assert_includes comment.mail_html, %(src="cid:pic1@mail")
    assert_includes comment.mail_html, "earlier message"
    assert_not_includes comment.mail_html, "script"
    assert_equal "pic1@mail", comment.files.sole.blob.metadata["content_id"]
  end

  test "the reply's frame points inline images at its own files and allows only that path" do
    comment = process_reply
    file = comment.files.sole
    sign_in users(:agent)
    get ticket_comment_mail_url(@ticket, comment)
    assert_response :success
    path = "/tickets/#{@ticket.number}/comments/#{comment.id}/mail/images/"
    assert_includes response.body, %(src="#{path}#{file.id}")
    assert_includes response.body, %(alt="Gone")
    assert_not_includes response.body, "cid:"
    policy = response.headers["Content-Security-Policy"]
    assert_includes policy, "img-src data: http://www.example.com#{path};"
    assert_not_includes policy[/img-src[^;]*/], "'self'"
    assert_includes policy, "default-src 'none'"

    get ticket_comment_mail_image_url(@ticket, comment, file)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_includes response.headers["Content-Security-Policy"], "sandbox"
  end

  test "only image files of that very message are served, never SVG or other files" do
    comment = process_reply
    file = comment.files.sole
    sign_in users(:agent)
    get ticket_comment_mail_image_url(@ticket, comment, file)
    assert_response :success

    get ticket_mail_image_url(@ticket, file)
    assert_response :not_found
    other = @ticket.add_comment(author: users(:agent), body: "See attached")
    get ticket_comment_mail_image_url(@ticket, other, file)
    assert_response :not_found

    file.blob.update!(content_type: "image/svg+xml")
    get ticket_comment_mail_image_url(@ticket, comment, file)
    assert_response :not_found
    file.blob.update!(content_type: "image/png", metadata: file.blob.metadata.except("content_id"))
    get ticket_comment_mail_image_url(@ticket, comment, file)
    assert_response :not_found
  end

  test "the requester sees their reply's frame; outsiders and internal notes do not" do
    comment = process_reply
    file = comment.files.sole
    sign_in users(:anna)
    get ticket_comment_mail_url(@ticket, comment)
    assert_response :success

    note = @ticket.add_comment(author: users(:agent), body: "Internal", internal: true)
    Comment.where(id: note.id).update_all(mail_html: "<p>STAFF-ONLY</p>")
    get ticket_comment_mail_url(@ticket, note)
    assert_response :not_found

    sign_in users(:boris)
    get tickets_url  # a first page keeps the new session; a 404 alone would not
    assert_response :success
    get ticket_comment_mail_url(@ticket, comment)
    assert_response :not_found
    get ticket_comment_mail_image_url(@ticket, comment, file)
    assert_response :not_found

    sign_out :user
    get ticket_comment_mail_url(@ticket, comment)
    assert_redirected_to new_user_session_url
  end

  test "the ticket page shows the reply with tabs and its own frame, not on the shared page" do
    comment = process_reply
    sign_in users(:agent)
    get ticket_url(@ticket)
    text = ActionView::RecordIdentifier.dom_id(comment, :mail_text)
    assert_select ".timeline [data-mail-view][data-text-pane=?]", text do
      assert_select "iframe.mail-frame[src=?]", ticket_comment_mail_path(@ticket, comment)
      assert_select "[data-mail-tab=text][aria-controls=?]", text
      assert_select ".mail-view__images", 0
    end
    assert_select "##{text} [data-message-text]", /Here is the photo/
    assert_select "[data-mail-view]", 1

    @ticket.share!(actor: users(:agent))
    sign_out :user
    get shared_ticket_url(@ticket.share_token)
    assert_response :success
    assert_select "[data-mail-view]", 0
    assert_select "iframe", 0
    assert_includes response.body, "Here is the photo."
  end

  test "a new ticket's inline image shows in its frame too" do
    raw = mail_with_image(subject: "Broken display", html: %(<p>Look:</p><img src="cid:pic1@mail">))
    assert_equal :ticket, MailboxMessage.new(@org, raw).process
    ticket = Ticket.order(:id).last
    file = ticket.files.sole
    sign_in users(:agent)
    get ticket_mail_url(ticket)
    assert_includes response.body, %(src="/tickets/#{ticket.number}/mail/images/#{file.id}")
    get ticket_mail_image_url(ticket, file)
    assert_response :success
  end
end
