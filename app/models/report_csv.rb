# One table of the reports page as CSV (specs/reports.md "CSV export").
class ReportCsv
  TABLES = %w[volume burndown statuses organizations people].freeze
  BOM = "\uFEFF".freeze
  FORMULA_START = /\A[=+\-@\t\r]/

  def initialize(report, table)
    @report = report
    @table = table.to_s
    raise ActiveRecord::RecordNotFound unless TABLES.include?(@table)
  end

  def filename
    "stopan-#{@table}-#{@report.period_slug}-#{@report.now.to_date.iso8601}.csv"
  end

  # UTF-8 with a byte order mark, every field quoted, CRLF line ends.
  def to_s
    BOM + [ header, *rows ].map { |row| row.map { |cell| quote(cell) }.join(",") + "\r\n" }.join
  end

  private

  def header = send("#{@table}_header")
  def rows = send("#{@table}_rows")

  def volume_header = [ unit, t("series.created"), t("series.done") ]
  def volume_rows = @report.buckets.map { |bucket| [ date(bucket.starts_at), bucket.created, bucket.done ] }

  def burndown_header = [ unit, t("series.open") ]
  def burndown_rows = @report.burndown.map { |point| [ date(point.starts_at), point.open ] }

  def statuses_header = [ I18n.t("ui.fields.status"), t("csv.stage"), t("csv.count") ]

  def statuses_rows
    @report.status_rows.map { |row| [ I18n.t("ui.statuses.#{row.status}"), row.stage&.name, row.count ] }
  end

  def organizations_header
    [ I18n.t("ui.fields.organization"), t("columns.created"), t("columns.done"), t("columns.open"),
      seconds("first_response"), seconds("resolution") ]
  end

  def organizations_rows
    @report.organization_rows.map do |row|
      [ row.organization.name, row.created, row.done, row.open, whole(row.first_response), whole(row.resolution) ]
    end
  end

  def people_header
    [ t("columns.person"), t("csv.role"), t("columns.assigned_open"), t("columns.done"), t("columns.replies"),
      t("columns.notes"), seconds("first_response") ]
  end

  def people_rows
    @report.person_rows.map do |row|
      [ row.user.display_name, I18n.t("ui.roles.#{row.user.role}"), row.open, row.done, row.replies, row.notes,
        whole(row.first_response) ]
    end
  end

  def t(key) = I18n.t("ui.reports.#{key}")
  def unit = t("units.#{@report.unit}")
  def seconds(column) = I18n.t("ui.reports.csv.seconds", column: t("columns.#{column}"))
  def date(time) = time.to_date.iso8601
  def whole(duration) = duration&.round

  # Text that a spreadsheet would run as a formula gets an apostrophe.
  def quote(cell)
    text = cell.to_s
    text = "'#{text}" if cell.is_a?(String) && text.match?(FORMULA_START)
    %("#{text.gsub('"', '""')}")
  end
end
