module Api
  module V1
    # The token's user (specs/api.md); answers without a membership too.
    class MeController < BaseController
      def show
        render json: { user: me_json(current_user) }
      end

      # The language of emails and API messages; staff also the "new ticket"
      # emails (specs/notifications.md).
      def update
        changes = params.expect(user: %i[language notify_new_tickets])
        current_user.choose_language!(changes[:language]) if changes.key?(:language)
        current_user.update!(notify_new_tickets: flag(changes[:notify_new_tickets])) if changes.key?(:notify_new_tickets) && current_user.staff?
        render json: { user: me_json(current_user.reload) }
      end

      private

      def allowed_without_organization?
        true
      end
    end
  end
end
