# Statistics for staff (specs/reports.md): over the tickets the viewer may
# see, for one period and optionally one organization.
class ReportsController < ApplicationController
  def show
    authorize!(current_user.staff?)
    @report = TicketReport.new(current_user, params)
    respond_to do |format|
      format.html
      # One table of the page as a file (specs/reports.md "CSV export").
      format.csv do
        csv = ReportCsv.new(@report, params[:table])
        send_data csv.to_s, filename: csv.filename, type: "text/csv; charset=utf-8", disposition: "attachment"
      end
    end
  end
end
