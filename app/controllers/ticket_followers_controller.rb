# Staff followers and people in Cc on a ticket (specs/followers.md): for
# staff who may update the ticket, for a person in Cc who leaves, and for
# the requester who adds colleagues.
class TicketFollowersController < ApplicationController
  before_action :set_ticket

  # user_id: a staff member (themselves or a colleague); email: someone in Cc.
  # From the requester, user_id is a colleague for Cc.
  def create
    return add_colleague if policy.add_cc? && params[:email].blank?

    authorize!(may_manage?)
    follower = if params[:email].present?
      @ticket.add_cc!(params[:email], actor: current_user)
    else
      @ticket.add_staff_follower!(params[:user_id], actor: current_user)
    end
    return back(alert: @ticket.errors.full_messages.to_sentence) unless follower

    user = follower.user
    back(notice: if follower.cc? then t("flash.cc_added", name: user.display_name)
                 elsif user == current_user then t("flash.following")
                 else t("flash.follower_added", name: user.display_name)
                 end)
  end

  def destroy
    follower = @ticket.ticket_followers.find(params[:id])
    return leave(follower) if follower.cc? && follower.user == current_user

    authorize!(may_manage? || policy.remove_cc?(follower))
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
  end

  def policy
    @policy ||= TicketPolicy.new(current_user, @ticket)
  end

  def may_manage?
    current_user.staff? && policy.update?
  end

  # The requester adds a member of the organization to Cc
  # (specs/followers.md "The requester adds colleagues").
  def add_colleague
    follower = @ticket.add_cc_member!(params[:user_id], actor: current_user)
    back(notice: t("flash.cc_added", name: follower.user.display_name))
  end

  # A person in Cc leaves; the ticket is no longer theirs to see
  # (specs/followers.md "Leaving").
  def leave(follower)
    @ticket.leave!(follower)
    redirect_to tickets_path, notice: t("flash.cc_left", reference: @ticket.reference)
  end

  def back(**flash)
    redirect_to ticket_path(@ticket, anchor: "followers"), **flash
  end
end
