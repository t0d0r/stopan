module Api
  module V1
    # The OpenAPI description of the API (specs/api.md "OpenAPI"). It needs
    # no token: it describes the API and holds no data.
    class OpenapiController < ActionController::API
      def show
        expires_in 1.hour, public: true
        render json: OpenapiDocument.to_json
      end
    end
  end
end
