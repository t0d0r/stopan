module Api
  module V1
    # The numbers of the reports page for staff (specs/reports.md).
    class ReportsController < BaseController
      def show
        require_staff!
        report = TicketReport.new(current_user, params)
        render json: { report: report_json(report) }
      end

      private

      def report_json(report)
        {
          period: report.period, unit: report.unit, organization: report.organization && organization_json(report.organization),
          from: time_json(report.from), to: time_json(report.now),
          tiles: {
            created: report.created_count, created_before: report.previous_created_count,
            done: report.done_count, done_before: report.previous_done_count, open: report.open_count,
            waiting: report.waiting_count, first_response_median_seconds: report.first_response_median,
            resolution_median_seconds: report.resolution_median
          },
          buckets: report.buckets.map { |bucket| { starts_at: time_json(bucket.starts_at), created: bucket.created, done: bucket.done } },
          burndown: report.burndown.map { |point| { starts_at: time_json(point.starts_at), open: point.open } },
          statuses: report.status_rows.map { |row| { status: row.status, stage: row.stage && stage_json(row.stage), count: row.count } },
          organizations: report.organization_rows.map do |row|
            { organization: organization_json(row.organization), created: row.created, done: row.done, open: row.open,
              first_response_median_seconds: row.first_response, resolution_median_seconds: row.resolution }
          end,
          people: report.person_rows.map do |row|
            { user: user_json(row.user), open: row.open, done: row.done, replies: row.replies, notes: row.notes,
              first_response_median_seconds: row.first_response }
          end
        }
      end
    end
  end
end
