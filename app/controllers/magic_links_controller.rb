# One-time sign-in links for requesters (specs/public-form.md "Magic
# sign-in links"). Opening a link shows a "Sign in" button; only the POST
# signs in, so mail scanners that open links do not use them up.
class MagicLinksController < ApplicationController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  skip_before_action :authenticate_user!
  before_action :set_user, only: %i[show create_session]

  rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, name: "ip",
             with: -> { redirect_to new_magic_link_path, alert: t("flash.magic_too_many") }
  rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, name: "email",
             by: -> { params[:email].to_s.strip.downcase },
             with: -> { redirect_to new_magic_link_path, alert: t("flash.magic_too_many") }

  def new
  end

  # Sends a link when the address belongs to an active requester; the
  # answer is the same for every address.
  def create
    user = User.find_by("lower(email) = ?", params[:email].to_s.strip.downcase)
    AccountMailer.with(user: user).magic_link.deliver_later if user&.magic_sign_in_allowed?
    redirect_to new_user_session_path, notice: t("flash.magic_link_sent")
  end

  def show
    render :invalid, status: :not_found unless @user
  end

  def create_session
    return render(:invalid, status: :not_found) unless @user

    sign_in(@user)
    ticket = Ticket.visible_to(@user).find_by(number: params[:ticket].to_s) if params[:ticket].present?
    redirect_to ticket ? ticket_path(ticket) : tickets_path, notice: t("flash.magic_signed_in")
  end

  private

  def set_user
    user = User.find_by_token_for(:magic_sign_in, params[:token].to_s)
    @user = user if user&.magic_sign_in_allowed?
  end
end
