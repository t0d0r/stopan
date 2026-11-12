# Where a ticket stands against the first-response and resolution
# targets of its priority (specs/sla.md). Calendar time; nothing is
# stored but the ticket's first response.
class Sla
  KINDS = %w[first_response resolution].freeze
  MAX_MINUTES = 8760 * 60
  # A fifth of the target left counts as "soon".
  SOON = 0.2
  WAITING_STATUSES = %w[pending postponed].freeze

  # state: met, late, overdue, soon, running or waiting. `at` is when it
  # was answered or done; `seconds` the time that matters for the state:
  # left (soon, running), over (overdue, late) or taken (met).
  Mark = Struct.new(:kind, :state, :due_at, :target_minutes, :at, :seconds, keyword_init: true) do
    def warning? = %w[overdue late].include?(state)
  end

  # The tickets with a target overdue now (specs/sla.md "Overdue view"):
  # not Done, and past the first-response time without a staff reply, or
  # past the resolution time while New or In progress. The same rule as
  # the "overdue" state, in SQL; none without targets.
  def self.overdue(scope, targets: AppSetting.current.sla_targets, now: Time.current)
    conditions = Ticket::PRIORITIES.filter_map do |priority|
      first = targets.dig(priority, "first_response").to_i
      resolution = targets.dig(priority, "resolution").to_i
      parts = []
      parts << Ticket.sanitize_sql([ "(tickets.first_response_at IS NULL AND tickets.created_at < ?)", now - first.minutes ]) if first.positive?
      if resolution.positive?
        parts << Ticket.sanitize_sql([ "(tickets.status NOT IN (?) AND tickets.created_at < ?)", WAITING_STATUSES,
                                       now - resolution.minutes ])
      end
      Ticket.sanitize_sql([ "(tickets.priority = ? AND (#{parts.join(' OR ')}))", priority ]) if parts.any?
    end
    return scope.none if conditions.empty?

    scope.where.not(status: Ticket::DONE).where(conditions.join(" OR "))
  end

  def self.any_target?(targets = AppSetting.current.sla_targets)
    targets.values.any? { |kinds| kinds.to_h.values.any? { |minutes| minutes.to_i.positive? } }
  end

  attr_reader :ticket, :now

  def initialize(ticket, targets: AppSetting.current.sla_targets, now: Time.current)
    @ticket = ticket
    @targets = targets || {}
    @now = now
  end

  def first_response
    mark("first_response", ticket.first_response_at) { ticket.done? ? nil : open_state("first_response") }
  end

  def resolution
    mark("resolution", (ticket.done_at if ticket.done?)) do
      WAITING_STATUSES.include?(ticket.status) ? "waiting" : open_state("resolution")
    end
  end

  def marks
    [ first_response, resolution ].compact
  end

  # The mark the queue warns about: overdue before soon, else nothing.
  def alert
    open = marks.select { |mark| %w[overdue soon].include?(mark.state) }
    open.find { |mark| mark.state == "overdue" } || open.first
  end

  private

  def minutes(kind)
    value = @targets.dig(ticket.priority, kind).to_i
    value if value.positive?
  end

  def due(kind)
    ticket.created_at + minutes(kind).minutes
  end

  # A mark for the kind: closed (met or late) when `at` is given, else
  # the state the block returns, or nothing without a target or state.
  def mark(kind, at)
    return unless minutes(kind)

    due_at = due(kind)
    if at
      state = at <= due_at ? "met" : "late"
      seconds = state == "met" ? at - ticket.created_at : at - due_at
    else
      state = yield
      return unless state

      seconds = (due_at - now).abs
    end
    Mark.new(kind: kind, state: state, due_at: due_at, target_minutes: minutes(kind), at: at, seconds: seconds)
  end

  def open_state(kind)
    left = due(kind) - now
    if left.negative? then "overdue"
    elsif left < minutes(kind) * 60 * SOON then "soon"
    else "running"
    end
  end
end
