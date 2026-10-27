# The ticket list of GET /tickets: the agent queue for staff, "My tickets"
# for requesters (specs/queues.md). Every query starts from
# Ticket.visible_to, and the parameters only narrow it.
class TicketFilter
  STAFF_VIEWS = %w[unsolved mine unassigned pending postponed done all].freeze
  # A requester's own tickets (specs/queues.md "My tickets").
  REQUESTER_VIEWS = %w[open done all].freeze
  SORTS = %w[updated created priority].freeze
  PER_PAGE = 25
  # The advanced search fields (specs/queues.md "Advanced search"), staff only.
  ADVANCED = %i[words in_comments requester_q created_from created_to updated_from updated_to source files].freeze
  DATES = %i[created_from created_to updated_from updated_to].freeze
  # Text search over the subject and text, or also the replies and notes;
  # fixed SQL with the :pattern placeholder only.
  TEXT_SQL = "(ulower(tickets.subject) LIKE :pattern ESCAPE '\\' OR ulower(tickets.description) LIKE :pattern ESCAPE '\\')"
  TEXT_OR_COMMENTS_SQL = "(ulower(tickets.subject) LIKE :pattern ESCAPE '\\' OR ulower(tickets.description) LIKE :pattern ESCAPE '\\' " \
                         "OR EXISTS (SELECT 1 FROM comments WHERE comments.ticket_id = tickets.id " \
                         "AND ulower(comments.body) LIKE :pattern ESCAPE '\\'))"
  # "#1001" or "1001" also finds the ticket number.
  NUMBER_OR_TEXT_SQL = "tickets.number = :number OR #{TEXT_SQL}".freeze
  NUMBER_OR_TEXT_OR_COMMENTS_SQL = "tickets.number = :number OR #{TEXT_OR_COMMENTS_SQL}".freeze
  PRIORITY_ORDER = Arel.sql("CASE tickets.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 " \
                            "WHEN 'normal' THEN 2 ELSE 3 END")

  attr_reader :user, :view, :status, :priority, :assignee, :organization_id, :requester_id, :query, :sort, :page, :advanced

  def initialize(user, params)
    @user = user
    @view = params[:view].presence_in(views) || views.first
    @status = params[:status].presence_in(Ticket::STATUSES)
    @query = params[:q].to_s.squish.first(200).presence
    @sort = params[:sort].presence_in(SORTS) || "updated"
    @page = [ params[:page].to_i, 1 ].max
    @advanced = {}
    return unless user.staff?

    @priority = params[:priority].presence_in(Ticket::PRIORITIES)
    @assignee = parse_assignee(params[:assignee].to_s)
    @organization_id = Organization.find_by(id: params[:organization].to_s)&.id if params[:organization].present?
    # One requester's tickets (specs/people.md "Queue filter").
    @requester_id = User.find_by(id: params[:requester].to_s)&.id if params[:requester].present?
    @advanced = parse_advanced(params)
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
    [ status, priority, assignee, organization_id, requester_id, query ].any? || advanced.any?
  end

  # The filtered tickets of the current view, for the board (specs/board.md).
  def scope
    filtered
  end

  # Query parameters of the current list, for links that change one thing.
  def params_with(changes = {})
    { view: view, status: status, priority: priority, assignee: assignee, organization: organization_id,
      requester: requester_id, q: query, sort: (sort unless sort == "updated"), page: (page if page > 1) }
      .merge(advanced).merge(changes).compact_blank
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
    scope = advanced_search(scope) if advanced.any?
    scope
  end

  # Known values only; broken dates and unknown sources are dropped.
  def parse_advanced(params)
    fields = {}
    words = params[:words].to_s.squish.first(200)
    fields[:words] = words if words.present?
    fields[:in_comments] = "1" if params[:in_comments] == "1"
    requester_q = params[:requester_q].to_s.squish.first(100)
    fields[:requester_q] = requester_q if requester_q.present?
    DATES.each do |name|
      date = begin
        Date.iso8601(params[name].to_s)
      rescue Date::Error
        nil
      end
      fields[name] = date.iso8601 if date
    end
    fields[:source] = params[:source] if params[:source].in?(Ticket::SOURCES)
    fields[:files] = "1" if params[:files] == "1"
    fields
  end

  def advanced_search(scope)
    advanced[:words]&.split&.first(10)&.each { |word| scope = scope.where(text_condition, pattern: like(word)) }
    if (who = advanced[:requester_q])
      people = User.where("ulower(users.name) LIKE :pattern ESCAPE '\\' OR lower(users.email) LIKE :pattern ESCAPE '\\'",
                          pattern: like(who))
      scope = scope.where(requester_id: people.select(:id))
    end
    scope = scope.where(created_at: day_range(:created_from, :created_to)) if advanced[:created_from] || advanced[:created_to]
    scope = scope.where(updated_at: day_range(:updated_from, :updated_to)) if advanced[:updated_from] || advanced[:updated_to]
    scope = scope.where(source: advanced[:source]) if advanced[:source]
    scope = with_files(scope) if advanced[:files]
    scope
  end

  def like(text)
    "%#{Ticket.sanitize_sql_like(text.downcase)}%"
  end

  # Subject or text, and with "in_comments" also the replies and notes.
  def text_condition
    advanced[:in_comments] ? TEXT_OR_COMMENTS_SQL : TEXT_SQL
  end

  # Whole days in the app's time zone, both ends included.
  def day_range(from, to)
    first = Time.zone.parse(advanced[from]).beginning_of_day if advanced[from]
    last = Time.zone.parse(advanced[to]).end_of_day if advanced[to]
    first..last
  end

  def with_files(scope)
    on_ticket = ActiveStorage::Attachment.where(record_type: "Ticket", name: "files").select(:record_id)
    on_comment = Comment.where(id: ActiveStorage::Attachment.where(record_type: "Comment", name: "files").select(:record_id))
                        .select(:ticket_id)
    scope.where(id: on_ticket).or(scope.where(id: on_comment))
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
    pattern = like(query)
    if (number = query[/\A#?(\d{1,9})\z/, 1])
      sql = advanced[:in_comments] ? NUMBER_OR_TEXT_OR_COMMENTS_SQL : NUMBER_OR_TEXT_SQL
      scope.where(sql, number: number.to_i, pattern: pattern)
    else
      scope.where(text_condition, pattern: pattern)
    end
  end
end
