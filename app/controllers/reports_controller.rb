# Statistics for staff (specs/reports.md): over the tickets the viewer may
# see, for one period and optionally one organization.
class ReportsController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @report = TicketReport.new(current_user, params)
  end
end
