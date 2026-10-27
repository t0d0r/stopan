# The kanban board of tickets by status, for staff (specs/board.md).
class BoardsController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @board = TicketBoard.new(current_user, params)
    @staff = Ticket.assignable_staff_for(current_user).to_a
  end
end
