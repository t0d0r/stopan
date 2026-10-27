module Api
  module V1
    # The share link of a ticket (specs/sharing.md).
    class SharesController < BaseController
      before_action :set_ticket

      def create
        return render_invalid(@ticket) unless @ticket.share!(actor: current_user, password: params[:password].presence)

        render json: { shared: true, share_url: shared_ticket_url(@ticket.share_token), password: @ticket.share_password? },
               status: :created
      end

      def destroy
        @ticket.unshare!(actor: current_user)
        head :no_content
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:ticket_number])
        authorize!(policy_for(@ticket).share?)
      end
    end
  end
end
