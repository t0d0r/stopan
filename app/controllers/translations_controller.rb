# The "Translate" button on a message, for staff (specs/translation.md):
# asks DeepL for the viewer's language and returns to the message.
class TranslationsController < ApplicationController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, by: -> { current_user.id },
             with: -> { redirect_to ticket_path(params[:ticket_id]), alert: t("flash.translation_rate_limited") }

  def create
    @ticket = find_visible_ticket(params[:ticket_id])
    authorize!(current_user.staff? && Translation.available?)
    message, anchor = find_message
    begin
      Translation.translate!(message, I18n.locale)
      redirect_to_ticket @ticket, anchor: anchor
    rescue Translation::TooLong
      redirect_to_ticket @ticket, anchor: anchor, alert: t("flash.translation_too_long")
    rescue DeeplClient::Error => e
      # Never the text or the key.
      Rails.logger.warn("Translation of #{anchor} on ticket #{@ticket.number} failed: #{e.message}")
      redirect_to_ticket @ticket, anchor: anchor, alert: t("flash.translation_failed")
    end
  end

  private

  # "description" or "comment-<id>" of this ticket; anything else is 404.
  def find_message
    case params[:message].to_s
    when "description" then [ @ticket, "description" ]
    when /\Acomment-(\d+)\z/
      comment = @ticket.comments.find($1)
      [ comment, "event-#{comment.event.id}" ]
    else raise ActiveRecord::RecordNotFound
    end
  end
end
