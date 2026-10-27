module Api
  module V1
    # Board stages (specs/board.md "Stages"): staff read them,
    # administrators change them.
    class StagesController < BaseController
      before_action :require_staff!, only: :index
      before_action :require_admin!, except: :index
      before_action :set_stage, only: %i[update destroy move]

      def index
        render json: { stages: Stage.ordered.map { |stage| stage_json(stage) } }
      end

      def create
        stage = Stage.new(params.expect(stage: %i[status name color]))
        return render_invalid(stage) unless stage.save

        render json: { stage: stage_json(stage) }, status: :created
      end

      def update
        return render_invalid(@stage) unless @stage.update(params.expect(stage: %i[name color]))

        render json: { stage: stage_json(@stage) }
      end

      # Tickets in a deleted stage go back to the plain status.
      def destroy
        @stage.destroy
        head :no_content
      end

      def move
        @stage.move(params[:direction] == "up" ? -1 : 1)
        render json: { stages: Stage.ordered.map { |stage| stage_json(stage) } }
      end

      private

      def set_stage
        @stage = Stage.find(params[:id])
      end
    end
  end
end
