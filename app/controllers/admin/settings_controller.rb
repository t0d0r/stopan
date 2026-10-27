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

    # The DeepL key and the Google client secret are write-only: a blank
    # field keeps the stored one (specs/translation.md, specs/mail-oauth.md).
    def setting_params
      params.expect(app_setting: [ :auto_postpone_days, :default_look, :translation_enabled, :deepl_api_key, :remove_deepl_api_key,
                                   :google_client_id, :google_client_secret, :remove_google_client_secret ])
            .tap do |permitted|
              %i[deepl_api_key google_client_secret].each { |name| permitted.delete(name) if permitted[name].blank? }
            end
    end
  end
end
