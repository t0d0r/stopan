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

  test "other requesters cannot download anything" do
    sign_in users(:boris)
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

  test "files attached to the ticket itself" do
    ticket = Ticket.create!(subject: "With file", description: "See file", requester: users(:anna),
                            organization: organizations(:acme), actor: users(:anna), files: [ upload ])
    sign_in users(:anna)
    get ticket_attachment_url(ticket, ticket.files.first)
    assert_response :success
  end
end
