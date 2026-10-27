class ApplicationController < ActionController::Base
  # Raised when a signed-in user asks for an action their role does not
  # allow on something they can see (specs/roles.md).
  class NotAuthorized < StandardError; end

  around_action :switch_locale
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :check_impersonation
  before_action :require_organization, unless: :devise_controller?
  before_action { Current.user = current_user }
  before_action :remember_locale

  rescue_from NotAuthorized, with: :forbidden

  helper_method :impersonator, :without_organization?

  private

  # A requester or agent without a membership sees nothing but a notice
  # (specs/roles.md); administrators are never limited by membership.
  def without_organization?
    return @without_organization if defined?(@without_organization)

    @without_organization = user_signed_in? && !current_user.admin? && !current_user.memberships.exists?
  end

  def require_organization
    return unless without_organization?
    return head(:forbidden) if request.format.json?

    redirect_to no_organization_path
  end

  # The administrator behind an impersonation (specs/admin.md
  # "Impersonation"), or nil.
  def impersonator
    return unless session[:impersonator_id]

    @impersonator ||= User.find_by(id: session[:impersonator_id])
  end

  # An impersonation ends when its administrator may no longer start one
  # (demoted, deactivated or deleted): the whole session is dropped.
  def check_impersonation
    return unless session[:impersonator_id]
    return if user_signed_in? && Impersonation.allowed?(impersonator, current_user)

    reset_session
    redirect_to new_user_session_path, alert: t("flash.impersonation_ended")
  end

  # The user's chosen language, this browser's switch, the browser's
  # language, English (specs/ui.md "Language"). While impersonating, the
  # admin's switch comes first so it does not change the user's choice.
  def switch_locale(&action)
    chosen = current_user&.language
    locale = session[:impersonator_id] ? locale_from_cookie || chosen : chosen || locale_from_cookie
    I18n.with_locale(locale || locale_from_accept_language || I18n.default_locale, &action)
  end

  def locale_from_cookie
    cookies[:locale].presence_in(I18n.available_locales.map(&:to_s))
  end

  # Uses the first language in Accept-Language when the app has a translation for it.
  def locale_from_accept_language
    request.env["HTTP_ACCEPT_LANGUAGE"].to_s.scan(/^[a-z]{2}/).first
      .presence_in(I18n.available_locales.map(&:to_s))
  end

  # Emails to this user use the language of the browser they last used
  # (specs/notifications.md), unless they chose one; only a supported
  # Accept-Language is stored.
  def remember_locale
    return unless user_signed_in? && current_user.language.nil?

    locale = locale_from_accept_language
    current_user.update_column(:locale, locale) if locale && current_user.locale != locale
  end

  def authorize!(allowed)
    raise NotAuthorized unless allowed
  end

  def forbidden
    return head(:forbidden) if request.format.json?

    render "errors/forbidden", status: :forbidden
  end

  # Tickets outside the user's scope are "not found" (specs/roles.md).
  # Back to a message on the ticket page. Turbo drops the #anchor of a
  # redirect, so Turbo requests go to the bare page, which Turbo renders as
  # a refresh that keeps the scroll position (turbo_refreshes_with);
  # without Turbo the anchor scrolls to the message.
  def redirect_to_ticket(ticket, anchor:, **options)
    redirect_to ticket_path(ticket, anchor: (anchor unless request.headers["X-Turbo-Request-Id"])), **options
  end

  def find_visible_ticket(number)
    Ticket.visible_to(current_user).find_by!(number: number.to_s)
  end
end
