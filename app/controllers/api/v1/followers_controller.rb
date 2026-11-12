module Api
  module V1
    # Staff followers and people in Cc (specs/followers.md "In the API"):
    # the People panel's actions, with the same rules and model methods.
    class FollowersController < BaseController
      before_action :set_ticket

      # user_id: a staff member (themselves or a colleague); email: someone in Cc.
      # From the requester, user_id is a colleague for Cc.
      def create
        follower = if policy_for(@ticket).add_cc? && params[:email].blank?
          @ticket.add_cc_member!(params.require(:user_id), actor: current_user)
        elsif !may_manage?
          raise NotAuthorized
        elsif params[:email].present?
          @ticket.add_cc!(params[:email], actor: current_user)
        else
          @ticket.add_staff_follower!(params.require(:user_id), actor: current_user)
        end
        return render_invalid(@ticket) unless follower

        render json: { follower: follower_json(follower) }, status: :created
      end

      # Staff who may update the ticket, a person in Cc leaving, or the
      # requester on a row they added.
      def destroy
        follower = @ticket.ticket_followers.find(params[:id])
        if follower.cc? && follower.user == current_user
          @ticket.leave!(follower)
        else
          authorize!(may_manage? || policy_for(@ticket).remove_cc?(follower))
          @ticket.remove_follower!(follower, actor: current_user)
        end
        head :no_content
      end

      private

      def set_ticket
        @ticket = find_visible_ticket(params[:ticket_number])
      end

      def may_manage?
        current_user.staff? && policy_for(@ticket).update?
      end
    end
  end
end
