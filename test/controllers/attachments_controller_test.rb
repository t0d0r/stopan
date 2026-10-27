require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @public = @ticket.add_comment(author: users(:agent), body: "Manual attached", files: [ upload ]).files.first
    @internal = @ticket.add_comment(author: users(:agent), body: "Invoice", internal: true, files: [ upload ]).files.first
  end

  test "the requester downloads files of public replies, as attachments" do
    sign_in users(:anna)
    get ticket_attachment_url(@ticket, @public)
    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "hello from stopan\n", response.body
  end

  test "the requester cannot download files of internal notes" do
    sign_in users(:anna)
    get ticket_attachment_url(@ticket, @internal)
    assert_response :not_found
  end

  test "colleagues download public files only; other organizations nothing" do
    sign_in users(:boris)
    get ticket_attachment_url(@ticket, @public)
    assert_response :success
    get ticket_attachment_url(@ticket, @internal)
    assert_response :not_found

    sign_in users(:carl)
    get ticket_attachment_url(@ticket, @public)
    assert_response :not_found
  end

  test "an attachment cannot be fetched through another ticket" do
    sign_in users(:anna)
    get ticket_attachment_url(tickets(:old_question), @public)
    assert_response :not_found
  end

  test "staff download internal files" do
    sign_in users(:agent)
    get ticket_attachment_url(@ticket, @internal)
    assert_response :success
  end

  test "previews are inline, sandboxed, and only for previewable kinds" do
    files = @ticket.add_comment(author: users(:agent), body: "Files",
                                files: [ upload("dot.png", "image/png"), upload("blank.pdf", "application/pdf"),
                                         upload("notes.zip", "application/zip") ]).files.to_a
    image, pdf, zip = files.sort_by { |file| %w[image/png application/pdf application/zip].index(file.content_type) }
    sign_in users(:anna)

    get preview_ticket_attachment_url(@ticket, @public)
    assert_response :success
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal "default-src 'none'; sandbox", response.headers["Content-Security-Policy"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    get preview_ticket_attachment_url(@ticket, image)
    assert_equal "image/png", response.media_type
    assert_equal "default-src 'none'; sandbox", response.headers["Content-Security-Policy"]

    get preview_ticket_attachment_url(@ticket, pdf)
    assert_equal "application/pdf", response.media_type
    assert_equal "default-src 'none'; frame-ancestors 'self'", response.headers["Content-Security-Policy"]

    get preview_ticket_attachment_url(@ticket, zip)
    assert_response :not_found
    get preview_ticket_attachment_url(@ticket, @internal)
    assert_response :not_found
  end

  test "file links carry their preview kind and URL" do
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "a.file-link[href=?][data-preview-kind=text][data-preview-url=?]",
                  ticket_attachment_path(@ticket, @public), preview_ticket_attachment_path(@ticket, @public)
    assert_select "dialog[data-preview-dialog]"
  end

  test "files attached to the ticket itself" do
    ticket = Ticket.create!(subject: "With file", description: "See file", requester: users(:anna),
                            organization: organizations(:acme), actor: users(:anna), files: [ upload ])
    sign_in users(:anna)
    get ticket_attachment_url(ticket, ticket.files.first)
    assert_response :success
  end
end
