require "test_helper"

# Moving a card on the board (specs/board.md "Moving cards").
class TicketMovesTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:agent) }

  test "a fetch move changes the status, writes the event and answers 204" do
    ticket = tickets(:printer)
    assert_difference -> { ticket.events.where(action: "status_changed").count } do
      patch move_ticket_url(ticket), params: { status: "pending" }, headers: { "Accept" => "application/json" }
    end
    assert_response :no_content
    assert_equal "pending", ticket.reload.status
  end

  test "a refused transition answers 422 with the reason" do
    ticket = tickets(:printer)
    patch move_ticket_url(ticket), params: { status: "new" }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_content
    assert_match(/cannot change from/, response.body)
    assert_equal "open", ticket.reload.status
  end

  test "the Move menu form goes back to the board with a notice" do
    ticket = tickets(:printer)
    patch move_ticket_url(ticket), params: { status: "done" }, headers: { "Referer" => board_url }
    assert_redirected_to board_url
    assert_equal "Ticket #{ticket.reference} moved to Done.", flash[:notice]
  end

  test "requesters cannot move tickets" do
    sign_in users(:anna)
    patch move_ticket_url(tickets(:printer)), params: { status: "done" }, headers: { "Accept" => "application/json" }
    assert_response :forbidden
    assert_equal "open", tickets(:printer).reload.status
  end
end
