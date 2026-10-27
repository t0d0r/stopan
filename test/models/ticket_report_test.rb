require "test_helper"

# The numbers of the reports page (specs/reports.md "Definitions"), on an
# organization of their own so the fixtures do not count.
class TicketReportTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 10, 27, 12, 0)

  setup do
    travel_to NOW
    @org = Organization.create!(name: "Initech")
    Membership.create!(user: users(:anna), organization: @org)
    Membership.create!(user: users(:agent), organization: @org)
  end

  def ticket(created:, status: "new", done: nil, assignee: nil)
    Ticket.create!(subject: "T", description: "x", requester: users(:anna), organization: @org, actor: users(:agent)).tap do |t|
      t.update_columns(created_at: created, updated_at: created, status: status, done_at: done, assignee_id: assignee&.id)
    end
  end

  def reply(ticket, author:, at:, internal: false)
    Comment.where(id: ticket.add_comment(author: author, body: "r", internal: internal).id).update_all(created_at: at)
  end

  def report(period: "30d", user: users(:admin))
    TicketReport.new(user, { period: period, organization: @org.id.to_s })
  end

  test "new, done, open now and the previous period" do
    ticket(created: 2.days.ago)
    ticket(created: 3.days.ago, status: "done", done: 1.day.ago)
    ticket(created: 40.days.ago, status: "done", done: 10.days.ago)
    ticket(created: 50.days.ago, status: "open")  # reopened: done_at cleared
    ticket(created: 45.days.ago, status: "done", done: 35.days.ago)

    r = report
    assert_equal 2, r.created_count
    assert_equal 2, r.done_count
    assert_equal 2, r.open_count
    assert_equal 3, r.previous_created_count  # 40, 45 and 50 days ago
    assert_equal 1, r.previous_done_count
  end

  test "first response is the first public staff reply; medians; waiting" do
    a = ticket(created: 5.days.ago)
    reply(a, author: users(:anna), at: 5.days.ago + 10.minutes)             # requester: ignored
    reply(a, author: users(:agent), at: 5.days.ago + 20.minutes, internal: true) # note: ignored
    reply(a, author: users(:agent), at: 5.days.ago + 2.hours)
    reply(a, author: users(:admin), at: 5.days.ago + 3.hours)                # not the first
    b = ticket(created: 4.days.ago)
    reply(b, author: users(:admin), at: 4.days.ago + 4.hours)
    ticket(created: 1.day.ago)                                              # still waiting

    r = report
    assert_equal 3.hours.to_f, r.first_response_median                      # median of 2 h and 4 h
    assert_equal 1, r.waiting_count

    people = r.person_rows.index_by(&:user)
    assert_equal 2.hours.to_f, people[users(:agent)].first_response
    assert_equal 1, people[users(:agent)].replies
    assert_equal 1, people[users(:agent)].notes
    assert_equal 2, people[users(:admin)].replies
    assert_not people.key?(users(:anna)), "requesters are not people rows"
  end

  test "resolution median and per organization rows" do
    ticket(created: 3.days.ago, status: "done", done: 1.day.ago)
    ticket(created: 10.days.ago, status: "done", done: 9.days.ago)
    ticket(created: 20.days.ago, status: "done", done: 2.days.ago, assignee: users(:agent))
    ticket(created: 1.day.ago, status: "pending", assignee: users(:agent))

    r = report
    assert_equal 2.days.to_f, r.resolution_median
    row = r.organization_rows.sole
    assert_equal [ @org, 4, 3, 1 ], [ row.organization, row.created, row.done, row.open ]
    assert_equal 2.days.to_f, row.resolution
    agent = r.person_rows.find { |p| p.user == users(:agent) }
    assert_equal [ 1, 1 ], [ agent.open, agent.done ]
  end

  test "buckets per period: days, weeks from Monday, months" do
    ticket(created: NOW.beginning_of_day + 1.hour)
    ticket(created: 2.days.ago, status: "done", done: 1.day.ago)

    days = report(period: "7d").buckets
    assert_equal 7, days.size
    assert_equal NOW.beginning_of_day - 6.days, days.first.starts_at
    assert_equal [ 1, 0 ], [ days.last.created, days.last.done ]
    assert_equal [ 0, 1 ], [ days[-2].created, days[-2].done ]

    weeks = report(period: "90d").buckets
    assert weeks.all? { |b| b.starts_at.monday? }
    assert_equal 2, weeks.sum(&:created)

    months = report(period: "12m").buckets
    assert_equal 12, months.size
    assert_equal Time.zone.local(2025, 11, 1), months.first.starts_at
    assert_equal 2, months.last.created
  end

  test "open now by status lists every open status and busy stages" do
    stage = Stage.create!(status: "open", name: "Waiting for parts", color: "pink")
    ticket(created: 1.day.ago, status: "open").update_columns(stage_id: stage.id)
    ticket(created: 1.day.ago, status: "pending")
    rows = report.status_rows
    assert_equal %w[postponed new open open pending], rows.map(&:status)
    assert_equal [ 0, 0, 0, 1, 1 ], rows.map(&:count)
    assert_equal stage, rows[3].stage
  end

  test "only visible tickets count; an invisible organization is ignored; unknown periods fall back" do
    outsider = User.create!(email: "olga@example.com", password: "password12", role: "agent")
    Membership.create!(user: outsider, organization: organizations(:globex))
    ticket(created: 1.day.ago)

    r = TicketReport.new(outsider, { period: "5y", organization: @org.id.to_s })
    assert_equal "30d", r.period
    assert_nil r.organization
    assert_equal Ticket.where(organization: organizations(:globex), created_at: r.range).count, r.created_count
    assert_not_includes r.organization_rows.map(&:organization), @org
  end
end
