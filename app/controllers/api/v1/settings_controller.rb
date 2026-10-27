module Api
  module V1
    # Settings of the whole service desk, for administrators. The DeepL key
    # is write-only (specs/translation.md); the Google client is set in the
    # wizard only.
    class SettingsController < BaseController
      FIELDS = %i[auto_postpone_days default_look mailbox_polling mailbox_poll_seconds timeline_order
                  translation_enabled deepl_api_key remove_deepl_api_key].freeze

      before_action :require_admin!

      def show
        render json: { settings: settings_json(AppSetting.current) }
      end

      def update
        setting = AppSetting.current
        attributes = params.expect(settings: FIELDS)
        attributes.delete(:deepl_api_key) if attributes[:deepl_api_key].blank?
        return render_invalid(setting) unless setting.update(attributes)

        render json: { settings: settings_json(setting) }
      end

      private

      def settings_json(setting)
        {
          auto_postpone_days: setting.auto_postpone_days, default_look: setting.default_look,
          mailbox_polling: setting.mailbox_polling, mailbox_poll_seconds: setting.mailbox_poll_seconds,
          timeline_order: setting.timeline_order, translation_enabled: setting.translation_enabled,
          deepl_api_key_set: setting.deepl_api_key.present?, google_ready: setting.google_ready?
        }
      end
    end
  end
end
