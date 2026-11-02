# Staff followers and people in Cc on a ticket (specs/followers.md): for
# staff who may update the ticket.
class TicketFollowersController < ApplicationController
  before_action :set_ticket

  # user_id: a staff member (themselves or a colleague); email: someone in Cc.
  def create
    if params[:email].present?
      follower = @ticket.add_cc!(params[:email], actor: current_user)
      return back(alert: @ticket.errors.full_messages.to_sentence) unless follower

      back(notice: t("flash.cc_added", name: follower.user.display_name))
    else
      user = Ticket.assignable_staff(@ticket.organization_id).find(params[:user_id])
      return back(alert: t("ui.followers.refused.taken")) if @ticket.ticket_followers.exists?(user_id: user.id)

      @ticket.follow!(user, actor: current_user)
      back(notice: user == current_user ? t("flash.following") : t("flash.follower_added", name: user.display_name))
    end
  end

  def destroy
    follower = @ticket.ticket_followers.find(params[:id])
    @ticket.remove_follower!(follower, actor: current_user)
    notice = if follower.user == current_user then t("flash.not_following")
    elsif follower.cc? then t("flash.cc_removed", name: follower.user.display_name)
    else t("flash.follower_removed", name: follower.user.display_name)
    end
    back(notice: notice)
  end

  private

  def set_ticket
    @ticket = find_visible_ticket(params[:ticket_id])
    authorize!(TicketPolicy.new(current_user, @ticket).update?)
  end

  def back(**flash)
    redirect_to ticket_path(@ticket, anchor: "followers"), **flash
  end
end
