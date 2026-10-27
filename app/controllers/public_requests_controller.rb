# The public request page of an organization (specs/public-form.md): no
# sign-in, off until an administrator turns it on, and the same answer for
# every address so it reveals nothing about accounts.
class PublicRequestsController < ApplicationController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  # A form posted sooner than this after it was shown is a script.
  MINIMUM_SECONDS = 3

  skip_before_action :authenticate_user!
  before_action :set_organization
  before_action :send_signed_in_users_to_the_ticket_form, except: :thanks

  rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, name: "short", with: -> { too_many }
  rate_limit to: 20, within: 1.day, only: :create, store: RATE_LIMIT_STORE, name: "daily", with: -> { too_many }

  def show
    @request = PublicRequest.new
  end

  def create
    @request = PublicRequest.new(request_params.merge(organization: @organization, locale: I18n.locale.to_s))
    return answer(@request.email) if bot?
    return render(:show, status: :unprocessable_content) unless @request.valid?

    @request.submit
    answer(@request.email)
  end

  def thanks
    @email = flash[:public_request_email]
  end

  private

  def set_organization
    @organization = Organization.with_public_form.find_by(slug: params[:slug].to_s)
    render :missing, status: :not_found unless @organization
  end

  def send_signed_in_users_to_the_ticket_form
    redirect_to new_ticket_path if user_signed_in?
  end

  def request_params
    params.expect(public_request: %i[name email subject description markdown])
  end

  # The honeypot is filled, or the form is too old, too young or forged.
  def bot?
    return true if params[:website].present?

    shown_at = form_verifier.verified(params[:started].to_s, purpose: @organization.slug)
    shown_at.nil? || Time.current.to_i - shown_at.to_i < MINIMUM_SECONDS
  end

  def form_verifier
    Rails.application.message_verifier(:public_request_form)
  end
  helper_method :form_verifier

  def answer(email)
    flash[:public_request_email] = email.to_s.strip.first(254)
    redirect_to public_request_thanks_path(@organization.slug)
  end

  def too_many
    @request = PublicRequest.new
    flash.now[:alert] = t("flash.public_request_too_many")
    render :show, status: :too_many_requests
  end
end
