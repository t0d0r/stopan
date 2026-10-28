# The search page: text, filters and advanced search over every ticket the
# user may see, with the queue's table and bulk actions (specs/queues.md
# "Search page"). Staff only (403 for requesters); requesters search from the menu bar.
class SearchesController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @filter = TicketFilter.new(current_user, params.merge(view: "all"))
  end
end
