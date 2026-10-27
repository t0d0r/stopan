module Admin
  # Settings of the whole service desk (specs/board.md): automatic
  # postponing, and the board's stages.
  class SettingsController < BaseController
    def show
      @setting = AppSetting.current
    end

    def update
      @setting = AppSetting.current
      if @setting.update(params.expect(app_setting: [ :auto_postpone_days ]))
        redirect_to admin_settings_path, notice: t("flash.settings_saved")
      else
        render :show, status: :unprocessable_content
      end
    end
  end
end
