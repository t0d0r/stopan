# The kanban board of GET /tickets/board (specs/board.md): one column per
# status, cards ordered urgent first, then high, then latest activity.
# Filters and visibility come from TicketFilter.
class TicketBoard
  # Not now first, like Fizzy's NOT NOW lane (specs/board.md).
  ORDER_OF_COLUMNS = %w[postponed new open pending resolved closed].freeze
  COLLAPSED = %w[postponed resolved closed].freeze
  LIMITED = %w[resolved closed].freeze
  LIMIT = 50
  ORDER = Arel.sql("CASE tickets.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END")

  Column = Struct.new(:status, :tickets, :count, keyword_init: true) do
    def more = count - tickets.size
    def collapsed? = COLLAPSED.include?(status)
  end

  attr_reader :filter

  def initialize(user, params)
    @filter = TicketFilter.new(user, params.slice(:assignee, :organization, :q).merge(view: "all"))
  end

  def columns
    @columns ||= begin
      counts = filter.scope.group(:status).count
      ORDER_OF_COLUMNS.map do |status|
        tickets = filter.scope.where(status: status).includes(:requester, :assignee, :organization)
                        .order(ORDER, updated_at: :desc, id: :desc)
        tickets = tickets.limit(LIMIT) if LIMITED.include?(status)
        Column.new(status: status, tickets: tickets.to_a, count: counts.fetch(status, 0))
      end
    end
  end
end
