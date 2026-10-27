# The ticket list of GET /tickets: the agent queue for staff, "My tickets"
# for requesters (specs/queues.md). Every query starts from
# Ticket.visible_to, and the parameters only narrow it.
class TicketFilter
  STAFF_VIEWS = %w[unsolved mine unassigned pending postponed done all].freeze
  # A requester's own tickets (specs/queues.md "My tickets").
  REQUESTER_VIEWS = %w[open done all].freeze
  SORTS = %w[updated created priority].freeze
  PER_PAGE = 25
  PRIORITY_ORDER = Arel.sql("CASE tickets.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 " \
                            "WHEN 'normal' THEN 2 ELSE 3 END")

  attr_reader :user, :view, :status, :priority, :assignee, :organization_id, :requester_id, :query, :sort, :page

  def initialize(user, params)
    @user = user
    @view = params[:view].presence_in(views) || views.first
    @status = params[:status].presence_in(Ticket::STATUSES)
    @query = params[:q].to_s.squish.first(200).presence
    @sort = params[:sort].presence_in(SORTS) || "updated"
    @page = [ params[:page].to_i, 1 ].max
    return unless user.staff?

    @priority = params[:priority].presence_in(Ticket::PRIORITIES)
    @assignee = parse_assignee(params[:assignee].to_s)
    @organization_id = Organization.find_by(id: params[:organization].to_s)&.id if params[:organization].present?
    # One requester's tickets (specs/people.md "Queue filter").
    @requester_id = User.find_by(id: params[:requester].to_s)&.id if params[:requester].present?
  end

  def requester
    @requester ||= User.find_by(id: requester_id) if requester_id
  end

  def views
    user.staff? ? STAFF_VIEWS : REQUESTER_VIEWS
  end

  def counts
    @counts ||= views.index_with { |name| in_view(name).count }
  end

  def tickets
    @tickets ||= filtered.includes(:requester, :assignee, :organization, :stage)
                         .order(*order).limit(PER_PAGE).offset((page - 1) * PER_PAGE).to_a
  end

  def total_count
    @total_count ||= filtered.count
  end

  def total_pages
    [ (total_count.to_f / PER_PAGE).ceil, 1 ].max
  end

  def first_index
    total_count.zero? ? 0 : (page - 1) * PER_PAGE + 1
  end

  def last_index
    [ page * PER_PAGE, total_count ].min
  end

  def filtered?
    [ status, priority, assignee, organization_id, requester_id, query ].any?
  end

  # The filtered tickets of the current view, for the board (specs/board.md).
  def scope
    filtered
  end

  # Query parameters of the current list, for links that change one thing.
  def params_with(changes = {})
    { view: view, status: status, priority: priority, assignee: assignee, organization: organization_id,
      requester: requester_id, q: query, sort: (sort unless sort == "updated"), page: (page if page > 1) }
      .merge(changes).compact_blank
  end

  # The list's sort, also the board's order after golden cards.
  def order
    case sort
    when "created" then [ { created_at: :desc, id: :desc } ]
    when "priority" then [ PRIORITY_ORDER, { updated_at: :desc, id: :desc } ]
    else [ { updated_at: :desc, id: :desc } ]
    end
  end

  private

  def base
    Ticket.visible_to(user)
  end

  def own
    base.where(requester_id: user.id)
  end

  def in_view(name)
    return own_view(name) unless user.staff?

    case name
    when "unsolved", "open" then base.unsolved
    when "mine" then base.unsolved.where(assignee_id: user.id)
    when "unassigned" then base.unsolved.where(assignee_id: nil)
    when "pending" then base.where(status: "pending")
    when "postponed" then base.where(status: Ticket::POSTPONED)
    when "done" then base.done
    else base
    end
  end

  def own_view(name)
    case name
    when "open" then own.where(status: Ticket::OPEN_FOR_REQUESTER)
    when "done" then own.done
    else own
    end
  end

  def filtered
    scope = in_view(view)
    scope = scope.where(status: status) if status
    scope = scope.where(priority: priority) if priority
    scope = scope.where(organization_id: organization_id) if organization_id
    scope = scope.where(requester_id: requester_id) if requester_id
    scope = filter_assignee(scope) if assignee
    scope = search(scope) if query
    scope
  end

  def parse_assignee(value)
    return value if %w[me none].include?(value)

    User.staff.find_by(id: value)&.id&.to_s if value.present?
  end

  def filter_assignee(scope)
    case assignee
    when "me" then scope.where(assignee_id: user.id)
    when "none" then scope.where(assignee_id: nil)
    else scope.where(assignee_id: assignee)
    end
  end

  # "#1001" or "1001" also finds the ticket number; LIKE wildcards in the
  # text are escaped.
  def search(scope)
    pattern = "%#{Ticket.sanitize_sql_like(query.downcase)}%"
    text = "ulower(tickets.subject) LIKE :pattern ESCAPE '\\' OR ulower(tickets.description) LIKE :pattern ESCAPE '\\'"
    if (number = query[/\A#?(\d{1,9})\z/, 1])
      scope.where("tickets.number = :number OR #{text}", number: number.to_i, pattern: pattern)
    else
      scope.where(text, pattern: pattern)
    end
  end
end
