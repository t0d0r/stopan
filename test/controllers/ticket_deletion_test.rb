require "test_helper"

# Soft delete of tickets and restoring them (specs/tickets.md "Deleting").
class TicketDeletionTest < ActionDispatch::IntegrationTest
  setup { @ticket = tickets(:printer) }

  test "an agent deletes a ticket: it is gone for everyone, its link stops, the history records it" do
    @ticket.share!(actor: users(:agent))
    token = @ticket.share_token
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#properties-title ~ form.button_to[action=?][data-confirm] button", ticket_path(@ticket), "Delete ticket"

    delete ticket_url(@ticket)
    assert_redirected_to tickets_url
    assert_equal "Ticket #1001 deleted. An administrator can restore it.", flash[:notice]
    @ticket.reload
    assert @ticket.deleted?
    assert_equal users(:agent), @ticket.deleted_by
    assert_not @ticket.shared?
    assert_equal %w[unshared deleted], @ticket.events.last(2).map(&:action)
    assert @ticket.events.last.internal?

    get tickets_url(view: "all")
    assert_select "td.ticket-number", text: "#1001", count: 0
    get ticket_url(@ticket)
    assert_response :not_found
    get shared_ticket_url(token)
    assert_response :not_found
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_response :not_found
    get tickets_url(view: "all")
    assert_select "td.ticket-number", text: "#1001", count: 0
  end

  test "requesters and agents of other organizations cannot delete" do
    sign_in users(:anna)
    delete ticket_url(@ticket)
    assert_response :forbidden
    assert_not @ticket.reload.deleted?

    sign_in users(:agent)
    delete ticket_url(tickets(:old_question))
    assert tickets(:old_question).reload.deleted?
  end

  test "administrators list deleted tickets, open them read-only and restore them" do
    @ticket.soft_delete!(actor: users(:agent))
    sign_in users(:admin)
    get admin_deleted_tickets_url
    assert_select "a.tab[aria-current=page]", "Deleted tickets"
    assert_select "tr#ticket_#{@ticket.id}" do
      assert_select "td", /Maria Agent/
      assert_select "form[action=?] button", restore_admin_deleted_ticket_path(@ticket), "Restore"
    end

    get ticket_url(@ticket)
    assert_response :success
    assert_select ".deleted-banner", /deleted by Maria Agent/
    assert_select "form.composer__form", 0
    assert_select "form.properties-form", 0
    assert_select "#sharing", 0
    assert_select "a.edit-link", 0
    post ticket_comments_url(@ticket), params: { comment: { body: "Still there?" } }
    assert_response :not_found

    patch restore_admin_deleted_ticket_url(@ticket)
    assert_redirected_to ticket_url(@ticket)
    assert_not @ticket.reload.deleted?
    assert_equal "restored", @ticket.events.last.action
    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_response :success

    sign_in users(:agent)
    get admin_deleted_tickets_url
    assert_redirected_to root_url
  end

  test "bulk delete with a confirmation, and the API" do
    sign_in users(:agent)
    get tickets_url
    assert_select "#bulk-form button[name=delete][value='1'][data-confirm]", "Delete"
    patch bulk_tickets_url, params: { numbers: %w[1001 1002], delete: "1" }
    assert_equal "2 tickets deleted.", flash[:notice]
    assert tickets(:printer).reload.deleted? && tickets(:email_account).reload.deleted?

    agent = users(:agent).api_tokens.create!(name: "t").plain_token
    delete api_v1_ticket_url(tickets(:vpn)), headers: { "Authorization" => "Bearer #{agent}" }
    assert_response :no_content
    assert tickets(:vpn).reload.deleted?

    admin = users(:admin).api_tokens.create!(name: "t").plain_token
    get api_v1_deleted_tickets_url, headers: { "Authorization" => "Bearer #{admin}" }
    assert_equal [ 1001, 1002, 1003 ], response.parsed_body["tickets"].map { |ticket| ticket["number"] }.sort
    post restore_api_v1_deleted_ticket_url(tickets(:vpn)), headers: { "Authorization" => "Bearer #{admin}" }
    assert_response :success
    assert_not tickets(:vpn).reload.deleted?
    get api_v1_deleted_tickets_url, headers: { "Authorization" => "Bearer #{agent}" }
    assert_response :forbidden
  end

  test "a mail reply to a deleted ticket starts a new one" do
    org = organizations(:acme)
    org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk", mailbox_address: "support@acme.example")
    @ticket.soft_delete!(actor: users(:agent))
    mail = Mail.new do
      from "anna@example.com"
      to "support@acme.example"
      subject "Re: [Stopan #1001] Receipt printer prints blank pages"
      body "Any news?"
    end
    assert_difference -> { Ticket.count } => 1, -> { @ticket.comments.count } => 0 do
      MailboxMessage.new(org, mail.to_s).process
    end
  end
end
