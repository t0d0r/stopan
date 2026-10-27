module Users
  # The language choice on the account page: English, Bulgarian, or the
  # browser's (specs/ui.md "Language"). This browser's switch cookie
  # follows it.
  class LanguagesController < ApplicationController
    def update
      authorize!(!impersonator)
      current_user.choose_language!(params.dig(:user, :language))
      if current_user.language
        cookies.permanent[:locale] = { value: current_user.language, same_site: :lax }
      else
        cookies.delete(:locale)
      end
      I18n.with_locale(current_user.language || locale_from_accept_language || I18n.default_locale) do
        redirect_to edit_user_registration_path, notice: t("flash.language_saved")
      end
    end
  end
end
