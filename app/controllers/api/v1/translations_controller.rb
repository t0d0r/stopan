module Api
  module V1
    # DeepL translation of a request or comment, for staff when an
    # administrator switched it on (specs/translation.md).
    class TranslationsController < BaseController
      def create
        ticket = find_visible_ticket(params[:ticket_number])
        authorize!(current_user.staff? && Translation.available?)
        message = case params[:message].to_s
        when "description" then ticket
        when /\Acomment-(\d+)\z/ then Comment.visible_to(current_user).where(ticket: ticket).find($1)
        else raise ActiveRecord::RecordNotFound
        end
        language = params[:language].to_s.presence_in(I18n.available_locales.map(&:to_s)) || I18n.locale.to_s
        translation = Translation.translate!(message, language)
        render json: { translation: { source_language: translation.source_language, target_language: translation.target_language,
                                      text: translation.text } }
      rescue Translation::TooLong
        render_error(:invalid, :unprocessable_content, message: I18n.t("flash.translation_too_long"))
      rescue DeeplClient::Error => e
        Rails.logger.warn("API translation on ticket #{params[:ticket_number]} failed: #{e.message}")
        render_error(:invalid, :bad_gateway, message: I18n.t("flash.translation_failed"))
      end
    end
  end
end
