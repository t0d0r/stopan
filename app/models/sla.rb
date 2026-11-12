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
