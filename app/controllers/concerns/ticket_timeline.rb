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
    comment = [ :author, :edited_by, { files_attachments: :blob } ]
    comment << { revisions: :editor } if policy.see_revisions?
    @events = TicketEvent.visible_to(current_user).where(ticket: @ticket)
                         .includes(:actor, comment: comment)
                         .order(:created_at, :id).to_a
    @staff = User.staff.active.ordered.to_a if current_user.staff?
  end
end
