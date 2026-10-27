# The kanban board of GET /tickets/board (specs/board.md): one column per
# status, each followed by its stages (staff-defined sub-columns); cards
# ordered urgent first, then high, then latest activity. Filters and
# visibility come from TicketFilter.
class TicketBoard
  # Not now first, like Fizzy's NOT NOW lane.
  ORDER_OF_COLUMNS = %w[postponed new open pending resolved closed].freeze
  COLLAPSED = %w[postponed resolved closed].freeze
  LIMITED = %w[resolved closed].freeze
  LIMIT = 50
  ORDER = Arel.sql("CASE tickets.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END")

  Column = Struct.new(:status, :stage, :tickets, :count, keyword_init: true) do
    def more = count - tickets.size
    def collapsed? = stage.nil? && COLLAPSED.include?(status)
    def key = stage ? "stage-#{stage.id}" : status
  end

  attr_reader :filter

  def initialize(user, params)
    @filter = TicketFilter.new(user, params.slice(:assignee, :organization, :q).merge(view: "all"))
  end

  def stages
    @stages ||= Stage.ordered.group_by(&:status)
  end

  def columns
    @columns ||= begin
      counts = filter.scope.group(:status, :stage_id).count
      ORDER_OF_COLUMNS.flat_map do |status|
        [ column(status, nil, counts), *stages.fetch(status, []).map { |stage| column(status, stage, counts) } ]
      end
    end
  end

  private

  def column(status, stage, counts)
    tickets = filter.scope.where(status: status, stage_id: stage&.id).includes(:requester, :assignee, :organization, :stage)
                    .order(ORDER, updated_at: :desc, id: :desc)
    tickets = tickets.limit(LIMIT) if LIMITED.include?(status)
    Column.new(status: status, stage: stage, tickets: tickets.to_a, count: counts.fetch([ status, stage&.id ], 0))
  end
end
