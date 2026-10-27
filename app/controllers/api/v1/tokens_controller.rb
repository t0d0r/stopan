module Api
  module V1
    # The user's own tokens: listed and revoked, never made here
    # (specs/api.md "Tokens").
    class TokensController < BaseController
      def index
        render json: { tokens: current_user.api_tokens.newest_first.map { |token| token_json(token) } }
      end

      def destroy
        current_user.api_tokens.find(params[:id]).destroy!
        head :no_content
      end

      private

      def allowed_without_organization?
        true
      end
    end
  end
end
