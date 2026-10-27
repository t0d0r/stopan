# The kanban board of tickets by status, for staff (specs/board.md).
class BoardsController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @board = TicketBoard.new(current_user, params)
    @staff = User.staff.active.ordered.to_a
  end
end
