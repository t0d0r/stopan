# Loads what the ticket page shows, filtered for the signed-in user
# (specs/timeline.md). Shared by the ticket and comment controllers, which
# both render tickets/show.
module TicketTimeline
  extend ActiveSupport::Concern

  included do
    helper_method :policy
  end

  private

  def policy
    @policy ||= TicketPolicy.new(current_user, @ticket)
  end

  def prepare_timeline
    @events = TicketEvent.visible_to(current_user).where(ticket: @ticket)
                         .includes(:actor, comment: [ :author, { files_attachments: :blob } ])
                         .order(:created_at, :id).to_a
    @staff = User.staff.active.ordered.to_a if current_user.staff?
  end
end
