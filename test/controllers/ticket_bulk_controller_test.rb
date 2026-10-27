require "test_helper"

# Bulk actions of the queue and search (specs/queues.md "Bulk actions").
class TicketBulkControllerTest < ActionDispatch::IntegrationTest
  ALL = %w[1001 1002 1003 1004].freeze

  test "the queue has row check boxes joined to the bulk form" do
    sign_in users(:agent)
    get tickets_url(view: "all", q: "printer")
    assert_select "form#bulk-form[action=?] select[name='changes[status]']", bulk_tickets_path
    assert_select "form#bulk-form input[name=return_to][value=?]", "/tickets?q=printer&view=all"
    assert_select "form#bulk-form input[name='list[q]'][value=printer]"
    assert_select "input[type=checkbox][data-bulk-page]"
    assert_select "input[type=checkbox][name='numbers[]'][form=bulk-form][value='1001']"

    sign_in users(:anna)
    get tickets_url
    assert_select "#bulk-form", 0
  end

  test "selected tickets change one by one; disallowed transitions are skipped and named" do
    sign_in users(:agent)
    patch bulk_tickets_url, params: { numbers: ALL, changes: { status: "pending", priority: "high" }, return_to: "/tickets?view=all" }
    assert_redirected_to "/tickets?view=all"
    assert_equal %w[pending pending pending done], ALL.map { |number| Ticket.find_by!(number: number).status }
    assert_equal %w[high high high low], ALL.map { |number| Ticket.find_by!(number: number).priority }
    assert_equal "3 tickets changed.", flash[:notice]
    assert_match(/1 skipped: #1004 \(/, flash[:alert])
    assert TicketEvent.exists?(ticket: tickets(:printer), action: "status_changed", to_value: "pending")
  end

  test "the whole list by its filters, and assignees only where they may work" do
    sign_in users(:agent)
    patch bulk_tickets_url, params: { scope: "list", list: { view: "all", q: "printer" }, numbers: [ "1002" ],
                                      changes: { assignee: "me" } }
    assert_equal users(:agent), tickets(:printer).reload.assignee
    assert_nil tickets(:email_account).reload.assignee, "the list wins over stray numbers"

    patch bulk_tickets_url, params: { numbers: %w[1001 1003], changes: { assignee: users(:agent_two).id.to_s } }
    assert_equal users(:agent_two), tickets(:printer).reload.assignee

    patch bulk_tickets_url, params: { numbers: %w[1001], changes: { assignee: users(:anna).id.to_s } }
    assert_match(/#1001/, flash[:alert])
    assert_equal users(:agent_two), tickets(:printer).reload.assignee
  end

  test "nothing chosen, nothing selected, unsafe return paths and requesters" do
    sign_in users(:agent)
    patch bulk_tickets_url, params: { numbers: ALL, changes: { status: "" } }
    assert_equal "Choose a status, priority or assignee first.", flash[:alert]
    patch bulk_tickets_url, params: { changes: { status: "open" }, return_to: "https://evil.example/tickets" }
    assert_redirected_to tickets_url
    assert_equal "Select at least one ticket first.", flash[:alert]

    sign_in users(:anna)
    patch bulk_tickets_url, params: { numbers: %w[1001], changes: { status: "done" } }
    assert_response :forbidden
    assert_equal "open", tickets(:printer).reload.status
  end

  test "the API does the same" do
    token = users(:agent).api_tokens.create!(name: "bulk").plain_token
    patch api_v1_bulk_tickets_url, params: { numbers: ALL, changes: { status: "pending" } },
                                   headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal [ 1001, 1002 ], body["updated"].sort
    assert_equal [ 1003 ], body["unchanged"]
    assert_equal [ 1004 ], body["skipped"].map { |skip| skip["number"] }

    requester = users(:anna).api_tokens.create!(name: "bulk").plain_token
    patch api_v1_bulk_tickets_url, params: { numbers: ALL, changes: { status: "done" } },
                                   headers: { "Authorization" => "Bearer #{requester}" }, as: :json
    assert_response :forbidden
  end
end
