# Marks pending tickets without activity for the set number of days done
# (specs/board.md "Automatic done"), as a status change without an actor.
# Run hourly with AutoPostpone and by bin/rails stopan:close_pending.
module AutoDone
  STATUS = "pending".freeze

  def self.days
    AppSetting.current.auto_done_days
  end

  # Returns how many tickets were marked done.
  def self.run(days = self.days)
    return 0 unless days.positive?

    Ticket.where(status: STATUS).where(updated_at: ...days.days.ago).find_each.count do |ticket|
      ticket.apply_changes({ status: Ticket::DONE }, actor: nil)
    end
  end

  # Whole days until the ticket is marked done (0 = today), or nil when it
  # will not be.
  def self.days_left(ticket, days = self.days)
    return unless days.positive? && ticket.status == STATUS

    [ ((ticket.updated_at + days.days - Time.current) / 1.day).ceil, 0 ].max
  end
end
