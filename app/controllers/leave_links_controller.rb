# The link at the end of a follower's or Cc's email (specs/followers.md
# "Leaving"). Opening it shows one button; only the POST takes the person
# off the ticket, so mail scanners that open links change nothing. No
# sign-in: the signed token names the row.
class LeaveLinksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_organization
  before_action :set_follower
  around_action :follower_locale, if: -> { @follower }

  def show
  end

  def create
    @ticket.leave!(@follower)
    render :left
  end

  private

  def set_follower
    @follower = TicketFollower.find_by_token_for(:leave, params[:token].to_s)
    return render(:invalid, status: :not_found) unless @follower

    @ticket = @follower.ticket
    @cc = @follower.cc?
  end

  # The language of the person's emails, whoever opens the link.
  def follower_locale(&action)
    I18n.with_locale(@follower.user.mail_locale(@ticket.organization), &action)
  end
end
