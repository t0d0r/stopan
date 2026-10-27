module Admin
  # Board stages per status (specs/board.md "Stages").
  class StagesController < BaseController
    before_action :set_stage, only: %i[update destroy move]

    def create
      stage = Stage.new(stage_params)
      if stage.save
        redirect_to admin_settings_path(anchor: "stages"), notice: t("flash.stage_saved", name: stage.name)
      else
        redirect_to admin_settings_path(anchor: "stages"), alert: stage.errors.full_messages.to_sentence
      end
    end

    def update
      if @stage.update(stage_params.except(:status))
        redirect_to admin_settings_path(anchor: "stages"), notice: t("flash.stage_saved", name: @stage.name)
      else
        redirect_to admin_settings_path(anchor: "stages"), alert: @stage.errors.full_messages.to_sentence
      end
    end

    # Tickets in a deleted stage go back to the plain status.
    def destroy
      @stage.destroy
      redirect_to admin_settings_path(anchor: "stages"), notice: t("flash.stage_deleted", name: @stage.name)
    end

    def move
      @stage.move(params[:direction] == "up" ? -1 : 1)
      redirect_to admin_settings_path(anchor: "stages")
    end

    private

    def set_stage
      @stage = Stage.find(params[:id])
    end

    def stage_params
      params.expect(stage: %i[status name color])
    end
  end
end
