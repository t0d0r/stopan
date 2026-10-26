class ApplicationController < ActionController::Base
  # Raised when a signed-in user asks for an action their role does not
  # allow on something they can see (specs/roles.md).
  class NotAuthorized < StandardError; end

  around_action :switch_locale
  before_action :authenticate_user!, unless: :devise_controller?
  before_action { Current.user = current_user }
  before_action :remember_locale

  rescue_from NotAuthorized, with: :forbidden

  private

  def switch_locale(&action)
    I18n.with_locale(locale_from_accept_language || I18n.default_locale, &action)
  end

  # Uses the first language in Accept-Language when the app has a translation for it.
  def locale_from_accept_language
    request.env["HTTP_ACCEPT_LANGUAGE"].to_s.scan(/^[a-z]{2}/).first
      .presence_in(I18n.available_locales.map(&:to_s))
  end

  # Emails to this user use the language of the browser they last used
  # (specs/notifications.md); only a supported Accept-Language is stored.
  def remember_locale
    locale = locale_from_accept_language
    current_user.update_column(:locale, locale) if user_signed_in? && locale && current_user.locale != locale
  end

  def authorize!(allowed)
    raise NotAuthorized unless allowed
  end

  def forbidden
    render "errors/forbidden", status: :forbidden
  end

  # Tickets outside the user's scope are "not found" (specs/roles.md).
  def find_visible_ticket(number)
    Ticket.visible_to(current_user).find_by!(number: number.to_s)
  end
end
