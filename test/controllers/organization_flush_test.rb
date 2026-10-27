require "test_helper"

# Removing all tickets of an organization for good (specs/admin.md
# "Flush all tickets of an organization").
class OrganizationFlushTest < ActionDispatch::IntegrationTest
  setup do
    @acme = organizations(:acme)
    @acme.update!(notes: "Bakery", smtp_enabled: true, smtp_address: "smtp.acme.example", mail_from: "help@acme.example",
                  smtp_password: "mail-secret", public_form: true)
    sign_in users(:admin)
  end

  test "the danger zone asks for the exact name and removes every ticket with all that hangs on it" do
    printer = tickets(:printer)
    printer.files.attach(io: StringIO.new("hello"), filename: "note.txt", content_type: "text/plain")
    Translation.create!(translatable: printer, target_language: "bg", source_language: "en", text: "x", source_digest: "d")
    perform_enqueued_jobs { printer.add_comment(author: users(:agent), body: "Hi") }
    tickets(:email_account).soft_delete!(actor: users(:agent))
    acme_ids = @acme.tickets.pluck(:id)

    get admin_organization_url(@acme)
    assert_select "#danger-zone form[action=?]", flush_admin_organization_path(@acme) do
      assert_select "input[name=confirm_name][data-flush-name=?]", "Acme Bakery"
      assert_select "input[type=submit][data-flush-button][value=?]", "Delete all 3 tickets for good"
    end

    post flush_admin_organization_url(@acme), params: { confirm_name: "acme bakery" }
    assert_equal "The name did not match. Nothing was deleted.", flash[:alert]
    assert_equal 3, @acme.tickets.count

    post flush_admin_organization_url(@acme), params: { confirm_name: " Acme Bakery " }
    assert_redirected_to admin_organization_url(@acme)
    assert_equal "3 tickets of Acme Bakery were deleted for good.", flash[:notice]
    assert_equal 0, Ticket.where(id: acme_ids).count
    assert_equal 0, Comment.where(ticket_id: acme_ids).count
    assert_equal 0, TicketEvent.where(ticket_id: acme_ids).count
    assert_equal 0, Notification.where(ticket_id: acme_ids).count
    assert_equal 0, Translation.where(translatable_type: "Ticket", translatable_id: acme_ids).count
    assert_equal 0, ActiveStorage::Attachment.where(record_type: "Ticket", record_id: acme_ids).count
    assert tickets(:vpn).reload, "other organizations keep theirs"
  end

  test "nothing else of the organization changes, and numbers are never reused" do
    members = @acme.memberships.pluck(:user_id).sort
    highest = Ticket.maximum(:number)
    post flush_admin_organization_url(@acme), params: { confirm_name: "Acme Bakery" }
    @acme.reload
    assert_equal [ "Bakery", "smtp.acme.example", "help@acme.example", "mail-secret", true ],
                 [ @acme.notes, @acme.smtp_address, @acme.mail_from, @acme.smtp_password, @acme.public_form ]
    assert_equal members, @acme.memberships.pluck(:user_id).sort
    assert User.exists?(users(:anna).id)

    Ticket.where(number: highest).delete_all
    ticket = Ticket.create!(subject: "New", description: "After the flush", requester: users(:anna), organization: @acme, actor: users(:anna))
    assert_operator ticket.number, :>, highest
  end

  test "administrators only; the API needs the name too" do
    sign_in users(:agent)
    post flush_admin_organization_url(@acme), params: { confirm_name: "Acme Bakery" }
    assert_redirected_to root_url
    assert_equal 3, @acme.tickets.count

    token = users(:admin).api_tokens.create!(name: "t").plain_token
    post flush_api_v1_organization_url(@acme), params: { confirm_name: "Acme" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :unprocessable_content
    post flush_api_v1_organization_url(@acme), params: { confirm_name: "Acme Bakery" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_equal 3, response.parsed_body["removed"]
  end
end
