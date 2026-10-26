# Creates, replaces and stops a ticket's share link (specs/sharing.md).
class TicketSharesController < ApplicationController
  before_action :set_ticket

  def create
    if @ticket.share!(actor: current_user, password: params[:share_password])
      redirect_to ticket_path(@ticket, anchor: "sharing"), notice: t("flash.share_created")
    else
      redirect_to ticket_path(@ticket, anchor: "sharing"), alert: @ticket.errors.full_messages.to_sentence
    end
  end

  def destroy
    @ticket.unshare!(actor: current_user)
    redirect_back_or_to ticket_path(@ticket, anchor: "sharing"), allow_other_host: false,
                                                                notice: t("flash.share_stopped")
  end

  private

  def set_ticket
    @ticket = find_visible_ticket(params[:ticket_id])
    authorize! TicketPolicy.new(current_user, @ticket).share?
  end
end
