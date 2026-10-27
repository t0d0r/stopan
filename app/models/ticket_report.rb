# The numbers of the reports page (specs/reports.md), over the tickets the
# user may see (Ticket.visible_to), for one period and optionally one
# organization. Medians are computed in Ruby: SQLite has no percentiles.
class TicketReport
  PERIODS = %w[7d 30d 90d 12m].freeze
  UNITS = { "7d" => :day, "30d" => :day, "90d" => :week, "12m" => :month }.freeze

  Bucket = Struct.new(:starts_at, :created, :done, keyword_init: true)
  StatusRow = Struct.new(:status, :stage, :count, keyword_init: true)
  OrganizationRow = Struct.new(:organization, :created, :done, :open, :first_response, :resolution, keyword_init: true)
  PersonRow = Struct.new(:user, :open, :done, :replies, :notes, :first_response, keyword_init: true)

  attr_reader :user, :period, :organization, :now

  def initialize(user, params, now: Time.current)
    @user = user
    @now = now
    @period = params[:period].presence_in(PERIODS) || "30d"
    @organization = organizations.find_by(id: params[:organization].to_s) if params[:organization].present?
  end

  def organizations
    user.visible_organizations.order(:name)
  end

  def unit
    UNITS.fetch(period)
  end

  # Today and the days before it, or this month and the 11 before.
  def from
    today = now.beginning_of_day
    case period
    when "7d" then today - 6.days
    when "30d" then today - 29.days
    when "90d" then today - 89.days
    else now.beginning_of_month - 11.months
    end
  end

  def range
    from..now
  end

  # The same length just before the period, for the tiles' change.
  def previous_range
    (from - (now - from))...from
  end

  def created_count
    created_in(range).count
  end

  def previous_created_count
    created_in(previous_range).count
  end

  def done_count
    done_in(range).count
  end

  def previous_done_count
    done_in(previous_range).count
  end

  def open_count
    open.count
  end

  def first_response_median
    median(first_responses.values.filter_map { |first| first&.first })
  end

  # Tickets of the period with no public staff reply yet.
  def waiting_count
    first_responses.count { |_, first| first.nil? }
  end

  def resolution_median
    median(resolutions.map(&:last))
  end

  def buckets
    @buckets ||= begin
      created = created_in(range).pluck(:created_at).map { |time| bucket_of(time) }.tally
      done = done_in(range).pluck(:done_at).map { |time| bucket_of(time) }.tally
      bucket_starts.map { |start| Bucket.new(starts_at: start, created: created.fetch(start, 0), done: done.fetch(start, 0)) }
    end
  end

  # Open tickets per status and stage, in board order (board.md).
  def status_rows
    counts = open.group(:status, :stage_id).count
    stages = Stage.ordered.group_by(&:status)
    (TicketBoard::ORDER_OF_COLUMNS - [ Ticket::DONE ]).flat_map do |status|
      [ StatusRow.new(status: status, stage: nil, count: counts.fetch([ status, nil ], 0)),
        *stages.fetch(status, []).filter_map do |stage|
          count = counts.fetch([ status, stage.id ], 0)
          StatusRow.new(status: status, stage: stage, count: count) if count.positive?
        end ]
    end
  end

  def organization_rows
    created = created_in(range).group(:organization_id).count
    done = done_in(range).group(:organization_id).count
    opened = open.group(:organization_id).count
    first = first_responses_by(created_in(range).pluck(:id, :organization_id).to_h)
    resolved = resolutions.group_by(&:first).transform_values { |rows| median(rows.map(&:last)) }
    rows = (organization ? [ organization ] : organizations).map do |org|
      OrganizationRow.new(organization: org, created: created.fetch(org.id, 0), done: done.fetch(org.id, 0),
                          open: opened.fetch(org.id, 0), first_response: first[org.id], resolution: resolved[org.id])
    end
    rows.select { |row| [ row.created, row.done, row.open ].any?(&:positive?) }
        .sort_by { |row| [ -row.open, row.organization.name.downcase ] }
  end

  def person_rows
    opened = open.where.not(assignee_id: nil).group(:assignee_id).count
    done = done_in(range).where.not(assignee_id: nil).group(:assignee_id).count
    written = Comment.where(ticket_id: scope.select(:id), created_at: range).group(:author_id, :internal).count
    by_author = first_responses.values.compact.group_by(&:last).transform_values { |firsts| median(firsts.map(&:first)) }
    ids = opened.keys | done.keys | written.keys.map(&:first) | by_author.keys
    User.staff.where(id: ids).ordered.map do |person|
      PersonRow.new(user: person, open: opened.fetch(person.id, 0), done: done.fetch(person.id, 0),
                    replies: written.fetch([ person.id, false ], 0), notes: written.fetch([ person.id, true ], 0),
                    first_response: by_author[person.id])
    end
  end

  private

  def scope
    @scope ||= organization ? Ticket.visible_to(user).where(organization_id: organization.id) : Ticket.visible_to(user)
  end

  def created_in(times)
    scope.where(created_at: times)
  end

  # Done now and done within the times; reopening clears done_at.
  def done_in(times)
    scope.done.where(done_at: times)
  end

  def open
    scope.where.not(status: Ticket::DONE)
  end

  # Ticket id => [seconds to the first public staff reply, its author id],
  # or nil while there is none, for the tickets created in the period.
  def first_responses
    @first_responses ||= begin
      created = created_in(range).pluck(:id, :created_at).to_h
      firsts = {}
      Comment.joins(:author).where(ticket_id: created.keys, internal: false, users: { role: User::STAFF_ROLES })
             .order(:created_at, :id).pluck(:ticket_id, :created_at, :author_id)
             .each { |ticket_id, at, author_id| firsts[ticket_id] ||= [ at - created[ticket_id], author_id ] }
      created.keys.index_with { |id| firsts[id] }
    end
  end

  # Group key (organization id per ticket id) => median first response.
  def first_responses_by(key_of)
    first_responses.filter_map { |id, first| [ key_of[id], first.first ] if first }
                   .group_by(&:first).transform_values { |pairs| median(pairs.map(&:last)) }
  end

  # [organization id, seconds from created to done] per Done ticket of the period.
  def resolutions
    @resolutions ||= done_in(range).pluck(:organization_id, :created_at, :done_at)
                                   .map { |org_id, created, done| [ org_id, done - created ] }
  end

  def median(values)
    return if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  def bucket_of(time)
    time = time.in_time_zone
    case unit
    when :day then time.beginning_of_day
    when :week then time.beginning_of_week(:monday)
    else time.beginning_of_month
    end
  end

  def bucket_starts
    step = { day: 1.day, week: 1.week, month: 1.month }.fetch(unit)
    start = bucket_of(from)
    starts = []
    while start <= now
      starts << start
      start = bucket_of(start + step)
    end
    starts
  end
end
