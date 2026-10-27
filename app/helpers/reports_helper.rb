# Formatting and the column chart of the reports page (specs/reports.md).
module ReportsHelper
  # At most this many dates under the chart (half of them on phones).
  CHART_LABELS = 10

  # "45 min", "3 h 20 min", "2 d 4 h"; "-" when there is nothing to measure.
  def report_duration(seconds)
    return "-" if seconds.nil?

    minutes = (seconds / 60.0).round
    hours, minutes_left = minutes.divmod(60)
    days, hours_left = hours.divmod(24)
    if hours.zero? then t("ui.reports.duration.minutes", m: minutes)
    elsif days.zero? then minutes_left.zero? ? t("ui.reports.duration.hours", h: hours) : t("ui.reports.duration.hours_minutes", h: hours, m: minutes_left)
    else hours_left.zero? ? t("ui.reports.duration.days", d: days) : t("ui.reports.duration.days_hours", d: days, h: hours_left)
    end
  end

  # "+3", "-1", "0" against the previous period of the same length.
  def report_delta(now, before)
    difference = now - before
    t("ui.reports.vs_previous", delta: (difference.positive? ? "+#{difference}" : difference.to_s),
                                period: t("ui.reports.previous.#{@report.period}"))
  end

  def report_bucket_label(start, unit)
    case unit
    when :month then l(start.to_date, format: t("ui.reports.month_format"))
    else l(start.to_date, format: t("ui.reports.day_format"))
    end
  end

  # Rounded axis maximum and its ticks: 1, 2 or 5 times a power of ten.
  def report_ticks(max)
    return [ 1, [ 0, 1 ] ] if max.zero?

    step = [ 1, 2, 5 ].product([ 1, 10, 100, 1000, 10_000 ]).map { |a, b| a * b }.sort
                      .find { |candidate| (max.to_f / candidate).ceil <= 4 }
    top = (max.to_f / step).ceil * step
    [ top, (0..top).step(step).to_a ]
  end

  # One column with a 4px rounded top and a square base, as an SVG path.
  def report_column_path(x, width, y_top, y_base)
    radius = [ 4, width / 2.0, y_base - y_top ].min
    "M#{x},#{y_base}V#{(y_top + radius).round(2)}" \
      "Q#{x},#{y_top} #{(x + radius).round(2)},#{y_top}" \
      "H#{(x + width - radius).round(2)}" \
      "Q#{x + width},#{y_top} #{x + width},#{(y_top + radius).round(2)}" \
      "V#{y_base}Z"
  end
end
