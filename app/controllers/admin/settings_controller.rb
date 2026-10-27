module Admin
  # Settings of the whole service desk (specs/board.md): automatic
  # postponing, and the board's stages.
  class SettingsController < BaseController
    def show
      @setting = AppSetting.current
    end

    def update
      @setting = AppSetting.current
      if @setting.update(setting_params)
        redirect_to admin_settings_path, notice: t("flash.settings_saved")
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    # The DeepL key is write-only: a blank field keeps the stored one
    # (specs/translation.md). The Google client is set in the wizard
    # (Admin::GoogleSetupController).
    def setting_params
      params.expect(app_setting: [ :auto_postpone_days, :default_look, :translation_enabled, :deepl_api_key, :remove_deepl_api_key ])
            .tap { |permitted| permitted.delete(:deepl_api_key) if permitted[:deepl_api_key].blank? }
    end
  end
end
