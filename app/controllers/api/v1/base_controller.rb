module Api
  module V1
    # The JSON API (specs/api.md): a personal token instead of a session,
    # the same scopes and checks as the pages, JSON errors.
    class BaseController < ActionController::API
      include ApiRepresentation

      class NotAuthorized < StandardError; end

      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
      READ_METHODS = %w[GET HEAD].freeze

      before_action :authenticate_token!
      around_action :switch_locale
      before_action :refuse_write_with_read_only_token
      before_action :require_organization
      rate_limit to: 300, within: 1.minute, store: RATE_LIMIT_STORE, by: -> { @api_token.id },
                 with: -> {
                   response.headers["Retry-After"] = "60"
                   render_error(:rate_limited, :too_many_requests)
                 }

      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, :not_found) }
      rescue_from NotAuthorized, with: -> { render_error(:forbidden, :forbidden) }
      rescue_from ActionController::ParameterMissing, with: ->(error) { render_error(:bad_request, :bad_request, message: error.message) }
      rescue_from ActiveRecord::RecordInvalid, with: ->(error) { render_invalid(error.record) }

      private

      attr_reader :current_user

      # "Authorization: Bearer <token>" only; never from the query string.
      def authenticate_token!
        scheme, token = request.authorization.to_s.split(" ", 2)
        @api_token = ApiToken.authenticate(token.to_s.strip) if scheme.to_s.casecmp?("Bearer")
        unless @api_token
          response.headers["WWW-Authenticate"] = 'Bearer realm="Stopan"'
          return render_error(:unauthorized, :unauthorized)
        end

        @api_token.touch_used
        @current_user = @api_token.user
        Current.user = @current_user
      end

      def switch_locale(&action)
        I18n.with_locale(api_locale, &action)
      end

      # The user's chosen language, else English.
      def api_locale
        current_user&.language.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
      end

      # A read-only token may only read (specs/api.md "Tokens").
      def refuse_write_with_read_only_token
        render_error(:read_only, :forbidden) if @api_token.read_only? && !READ_METHODS.include?(request.request_method)
      end

      # Without a membership only /me answers, as on the pages (roles.md).
      def require_organization
        return if current_user.admin? || current_user.memberships.exists? || allowed_without_organization?

        render_error(:forbidden, :forbidden)
      end

      def allowed_without_organization?
        false
      end

      def authorize!(allowed)
        raise NotAuthorized unless allowed
      end

      def require_admin!
        authorize!(current_user.admin?)
      end

      def require_staff!
        authorize!(current_user.staff?)
      end

      def find_visible_ticket(number)
        Ticket.visible_to(current_user).find_by!(number: number.to_s)
      end

      def policy_for(ticket)
        TicketPolicy.new(current_user, ticket)
      end

      # JSON true/false, "1"/"0", "true"/"false".
      def flag(value)
        ActiveModel::Type::Boolean.new.cast(value) || false
      end

      def render_error(code, status, message: nil, details: nil)
        # Rescued errors arrive outside switch_locale, so the language is set here too.
        error = { code: code.to_s, message: message || I18n.t("api.errors.#{code}", locale: api_locale) }
        error[:details] = details if details.present?
        render json: { error: error }, status: status
      end

      def render_invalid(record)
        render_error(:invalid, :unprocessable_content, message: record.errors.full_messages.to_sentence,
                                                       details: record.errors.to_hash(true))
      end
    end
  end
end
