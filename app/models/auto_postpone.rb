# Moves tickets without activity for the set number of days to "Not now"
# (specs/board.md "Automatic postponing"), as a status change without an
# actor. Run hourly from the web process and by bin/rails
# stopan:postpone_inactive.
module AutoPostpone
  STATUSES = %w[new open pending].freeze
  # Cards due within this many days show the stamp.
  STAMP_DAYS = 7

  def self.days
    AppSetting.current.auto_postpone_days
  end

  # Returns how many tickets were postponed.
  def self.run(days = self.days)
    return 0 unless days.positive?

    Ticket.where(status: STATUSES).where(updated_at: ...days.days.ago).find_each.count do |ticket|
      ticket.apply_changes({ status: Ticket::POSTPONED }, actor: nil)
    end
  end

  # Whole days until the ticket is postponed (0 = today), or nil when it
  # will not be.
  def self.days_left(ticket, days = self.days)
    return unless days.positive? && STATUSES.include?(ticket.status)

    [ ((ticket.updated_at + days.days - Time.current) / 1.day).ceil, 0 ].max
  end

  def self.start(interval: 1.hour)
    @task ||= Concurrent::TimerTask.new(execution_interval: interval.to_i) do
      Rails.application.executor.wrap { run }
    rescue StandardError => e
      Rails.logger.error("Auto postpone: #{e.class}: #{e.message}")
    end.tap(&:execute)
  end
end
