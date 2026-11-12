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
    Membership.create!(user: users(:admin), organization: @org)
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

  def custom(from, to, user: users(:admin))
    TicketReport.new(user, { period: "custom", from: from, to: to, organization: @org.id.to_s })
  end

  # NOW is 2026-10-27 12:00.
  test "a custom range counts whole days, both ends included, up to the end of a past day" do
    ticket(created: Time.zone.local(2026, 10, 1, 0, 5))
    ticket(created: Time.zone.local(2026, 10, 10, 23, 55), status: "done", done: Time.zone.local(2026, 10, 10, 23, 58))
    ticket(created: Time.zone.local(2026, 10, 11, 0, 5))
    ticket(created: Time.zone.local(2026, 9, 30, 23, 55), status: "done", done: Time.zone.local(2026, 10, 12, 9, 0))
    ticket(created: Time.zone.local(2026, 9, 25, 9, 0))

    r = custom("2026-10-01", "2026-10-10")
    assert r.custom?
    assert_not r.invalid_range?
    assert_equal 10, r.days
    assert_equal Time.zone.local(2026, 10, 1), r.from
    assert_equal Time.zone.local(2026, 10, 10).end_of_day, r.till
    assert_equal 2, r.created_count
    assert_equal 1, r.done_count
    assert_equal 2, r.previous_created_count  # 21 to 30 September
    assert_equal 3, r.open_count              # now, whatever the range
    assert_equal :day, r.unit
    assert_equal 10, r.buckets.size
    # At the end of 10 October: 25 and 30 September and 1 October were open.
    assert_equal 3, r.burndown.last.open
    assert_equal({ period: "custom", from: "2026-10-01", to: "2026-10-10", organization: @org.id }, r.filter_params)
    assert_equal "2026-10-01_2026-10-10", r.period_slug
  end

  test "a custom range ends now when it reaches today or beyond; units follow its length" do
    r = custom("2026-10-20", "2027-01-01")
    assert_equal Date.new(2026, 10, 27), r.to_date
    assert_equal NOW, r.till
    assert_equal 8, r.days

    assert_equal :day, custom("2026-09-27", "2026-10-27").unit
    assert_equal :week, custom("2026-09-26", "2026-10-27").unit
    assert_equal :week, custom("2026-04-28", "2026-10-27").unit
    assert_equal :month, custom("2026-04-27", "2026-10-27").unit
    assert_equal 12, custom("2025-11-01", "2026-10-27").buckets.size
  end

  test "custom without dates is the last 30 days; dates that are no range fall back to them" do
    r = custom(nil, nil)
    assert_not r.invalid_range?
    assert_equal [ Date.new(2026, 9, 28), Date.new(2026, 10, 27) ], [ r.from_date, r.to_date ]
    assert_equal report.from, r.from

    [ [ "2026-10-10", "2026-10-01" ], [ "soon", "2026-10-01" ], [ "2026-10-01", "" ], [ "2026-11-01", "2026-11-05" ],
      [ "2026-02-30", "2026-10-01" ], [ "2023-10-23", "2026-10-27" ], [ "2026-10-01'--", "2026-10-02" ] ].each do |from, to|
      r = custom(from, to)
      assert r.invalid_range?, "#{from}..#{to}"
      assert_equal [ Date.new(2026, 9, 28), Date.new(2026, 10, 27) ], [ r.from_date, r.to_date ]
    end
    assert_not custom("2023-10-24", "2026-10-27").invalid_range?
    assert_not report.invalid_range?
  end

  test "SLA rows count kept and missed targets of the period, or nothing without targets" do
    assert_nil report.sla_rows
    AppSetting.current.update!(sla_targets: { "normal" => { "first_response" => 60, "resolution" => 1440 } })

    answered = ->(t, at) { t.update_columns(first_response_at: at) }
    answered.call(ticket(created: 5.days.ago, status: "done", done: 5.days.ago + 3.hours), 5.days.ago + 30.minutes)  # both kept
    answered.call(ticket(created: 4.days.ago, status: "done", done: 2.days.ago), 4.days.ago + 2.hours)               # both missed
    ticket(created: 3.days.ago)                                                                                       # unanswered, overdue
    ticket(created: 10.minutes.ago)                                                                                   # still running
    ticket(created: 2.days.ago, status: "done", done: 2.days.ago + 1.hour)                                            # done unanswered: kept resolution only
    ticket(created: 2.days.ago).update_columns(priority: "low")                                                       # no target
    answered.call(ticket(created: 60.days.ago, status: "done", done: 1.day.ago), 60.days.ago + 5.minutes)            # old: resolution only, missed

    first, resolution = report.sla_rows
    assert_equal [ "first_response", 1, 2, 3, 33 ], [ first.kind, first.met, first.missed, first.total, first.percent ]
    assert_equal [ "resolution", 2, 2, 50 ], [ resolution.kind, resolution.met, resolution.missed, resolution.percent ]

    empty = TicketReport.new(users(:admin), { period: "custom", from: "2026-01-01", to: "2026-01-02", organization: @org.id.to_s }).sla_rows
    assert_equal [ 0, nil ], [ empty.first.total, empty.first.percent ]
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

  test "burndown replays status changes, so reopened tickets count right" do
    a = ticket(created: 5.days.ago)
    TicketEvent.create!(ticket: a, action: "status_changed", from_value: "new", to_value: "done", created_at: 3.days.ago)
    TicketEvent.create!(ticket: a, action: "status_changed", from_value: "done", to_value: "open", created_at: 1.day.ago)
    a.update_columns(status: "open", done_at: nil)
    b = ticket(created: 4.days.ago, status: "done", done: 2.days.ago)
    TicketEvent.create!(ticket: b, action: "status_changed", from_value: "new", to_value: "done", created_at: 2.days.ago)
    ticket(created: 10.days.ago)

    points = report(period: "7d").burndown
    assert_equal 7, points.size
    # Day by day from 6 days ago: c only; c+a; c+a+b; a done; b done too; a reopened; now.
    assert_equal [ 1, 2, 3, 2, 1, 2, 2 ], points.map(&:open)
    assert_equal report.open_count, points.last.open
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
