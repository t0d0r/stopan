module Api
  module V1
    # A message from an administrator to users' notifications
    # (specs/notifications.md "Messages from administrators").
    class MessagesController < BaseController
      before_action :require_admin!

      def create
        message = AdminMessage.new(params.expect(message: %i[recipients text]).merge(sender: current_user))
        return render_invalid(message) unless message.valid?

        render json: { delivered: message.deliver }, status: :created
      end
    end
  end
end
