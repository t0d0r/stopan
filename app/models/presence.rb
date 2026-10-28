# Who has Stopan open now (specs/presence.md). Each open page of a signed-in
# user is one entry, added and removed by PresenceChannel. Kept in process
# memory like ShareViewers: Action Cable runs in the one Puma process with
# the async adapter, so channels and requests see the same map.
module Presence
  PAGES = Concurrent::Map.new
  STAFF_STREAM = [ :presence, :staff ].freeze
  # A page refresh or a visit leaves and joins again within this time.
  DELAY = 1
  # Tests announce by hand instead of waiting for the timer.
  SCHEDULE = !Rails.env.test?

  @lock = Mutex.new
  @announced = []

  class << self
    def join(key, user, ticket = nil)
      PAGES[key] = [ user.id, ticket&.id ]
      changed
    end

    def leave(key)
      changed if PAGES.delete(key)
    end

    def user_ids
      PAGES.values.map(&:first).uniq
    end

    def viewer_ids(ticket)
      PAGES.values.filter_map { |user_id, ticket_id| user_id if ticket_id == ticket.id }.uniq
    end

    # Staff pages get the signal; a requester's page only keeps them counted.
    def stream(user)
      user.staff? ? STAFF_STREAM : [ user, :presence ]
    end

    # Tells staff pages to fetch their view again when the set of (user,
    # ticket) pairs differs from the one last announced. The signal carries
    # no names. True when it signalled.
    def announce
      @lock.synchronize { @scheduled = nil }
      state = PAGES.values.uniq.sort_by { |user_id, ticket_id| [ user_id, ticket_id.to_i ] }
      return false if state == @announced

      @announced = state
      Turbo::StreamsChannel.broadcast_action_to(*STAFF_STREAM, action: "presence_refresh", target: "presence")
      true
    end

    def reset
      PAGES.clear
      @announced = []
    end

    private

    def changed
      return unless SCHEDULE

      @lock.synchronize do
        @scheduled ||= Concurrent::ScheduledTask.execute(DELAY) do
          Rails.application.executor.wrap { announce }
        rescue StandardError => e
          Rails.logger.error("Presence: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
