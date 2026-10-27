# The numbers of a person's profile (specs/people.md): over the tickets
# they requested that the viewer may see. Medians are computed in Ruby, as
# in TicketReport.
class PersonStats
  RECENT = 10

  attr_reader :person, :viewer

  def initialize(person, viewer, now: Time.current)
    @person = person
    @viewer = viewer
    @now = now
  end

  def tickets
    @tickets ||= Ticket.visible_to(viewer).where(requester_id: person.id)
  end

  def total = tickets.count
  def unsolved = tickets.unsolved.count
  def done = tickets.done.count
  def last_30_days = tickets.where(created_at: (@now - 30.days)..@now).count

  def by_source
    counts = tickets.group(:source).count
    Ticket::SOURCES.index_with { |source| counts.fetch(source, 0) }
  end

  # Seconds from opening to the first public reply by staff.
  def first_response_median
    created = tickets.pluck(:id, :created_at).to_h
    return if created.empty?

    firsts = Comment.joins(:author).where(ticket_id: created.keys, internal: false, users: { role: User::STAFF_ROLES })
                    .group(:ticket_id).minimum(:created_at)
    median(firsts.map { |ticket_id, at| at - created[ticket_id] })
  end

  # Seconds from opening to done, for done tickets.
  def resolution_median
    median(tickets.done.where.not(done_at: nil).pluck(:created_at, :done_at).map { |created, done| done - created })
  end

  def recent
    tickets.includes(:organization).order(updated_at: :desc, id: :desc).limit(RECENT)
  end

  private

  def median(values)
    values = values.compact.select { |value| value >= 0 }.sort
    return if values.empty?

    middle = values.size / 2
    values.size.odd? ? values[middle] : (values[middle - 1] + values[middle]) / 2.0
  end
end
