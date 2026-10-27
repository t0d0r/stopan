# Theme (light / dark), width and text size, kept in cookies so the layout can render
# them before any script runs. application.js sets the same cookies without a
# round trip; this action is the fallback without JavaScript. The language
# switch always comes here: a cookie, and the user's choice when signed in
# and not impersonating (specs/ui.md "Language").
class PreferencesController < ApplicationController
  THEMES = %w[light dark].freeze
  SCALES = %w[normal big extra].freeze
  WIDTHS = %w[normal wide].freeze
  LOOKS = AppSetting::LOOKS

  skip_before_action :authenticate_user!
  skip_before_action :require_organization

  def update
    remember :theme, params[:theme].presence_in(THEMES)
    remember :scale, params[:scale].presence_in(SCALES)
    remember :width, params[:width].presence_in(WIDTHS)
    # "default" goes back to the site's theme (ui.md "Themes").
    params[:look] == "default" ? cookies.delete(:look) : remember(:look, params[:look].presence_in(LOOKS))
    # The same for the order of the ticket timeline (timeline.md).
    if params[:timeline_order] == "default"
      cookies.delete(:timeline_order)
    else
      remember :timeline_order, params[:timeline_order].presence_in(AppSetting::TIMELINE_ORDERS)
    end
    remember_language params[:locale].presence_in(I18n.available_locales.map(&:to_s))
    redirect_back fallback_location: root_path
  end

  private

  def remember(name, value)
    cookies.permanent[name] = { value: value, same_site: :lax } if value
  end

  def remember_language(locale)
    return unless locale

    remember :locale, locale
    current_user.choose_language!(locale) if user_signed_in? && !impersonator
  end
end
