require "test_helper"

# specs/sla.md "States"
class SlaTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 12, 12, 0)
  TARGETS = { "urgent" => { "first_response" => 60, "resolution" => 480 },
              "normal" => { "first_response" => 0, "resolution" => 2880 } }.freeze

  setup { travel_to NOW }

  def ticket(created:, priority: "urgent", status: "new", answered: nil, done: nil)
    Ticket.create!(subject: "T", description: "x", requester: users(:anna), organization: organizations(:acme), actor: users(:anna)).tap do |t|
      t.update_columns(created_at: created, priority: priority, status: status, first_response_at: answered, done_at: done)
    end
  end

  def sla(ticket) = Sla.new(ticket, targets: TARGETS)

  test "a fresh ticket runs, then is soon, then overdue" do
    fresh = sla(ticket(created: 10.minutes.ago))
    assert_equal [ "running", "running" ], fresh.marks.map(&:state)
    assert_equal NOW + 50.minutes, fresh.first_response.due_at
    assert_equal 50.minutes.to_i, fresh.first_response.seconds.to_i
    assert_nil fresh.alert

    soon = sla(ticket(created: 49.minutes.ago))
    assert_equal "soon", soon.first_response.state
    assert_equal "first_response", soon.alert.kind

    late = sla(ticket(created: 3.hours.ago))
    assert_equal "overdue", late.first_response.state
    assert_equal 2.hours.to_i, late.first_response.seconds.to_i
    assert late.first_response.warning?
    assert_equal "running", late.resolution.state
    assert_equal "overdue", late.alert.state
  end

  test "an answer in time is met, a later one late; the same for done" do
    met = sla(ticket(created: 5.hours.ago, answered: 5.hours.ago + 35.minutes, status: "done", done: 1.hour.ago))
    assert_equal [ "met", 35.minutes.to_i ], [ met.first_response.state, met.first_response.seconds.to_i ]
    assert_equal [ "met", 4.hours.to_i ], [ met.resolution.state, met.resolution.seconds.to_i ]
    assert_nil met.alert

    late = sla(ticket(created: 20.hours.ago, answered: 15.hours.ago, status: "done", done: 2.hours.ago))
    assert_equal [ "late", 4.hours.to_i ], [ late.first_response.state, late.first_response.seconds.to_i ]
    assert_equal [ "late", 10.hours.to_i ], [ late.resolution.state, late.resolution.seconds.to_i ]
    assert late.resolution.warning?
    assert_nil late.alert
  end

  test "pending and postponed tickets wait without a warning; back in progress they are measured again" do
    waiting = ticket(created: 2.days.ago, answered: 2.days.ago + 10.minutes, status: "pending")
    assert_equal "waiting", sla(waiting).resolution.state
    assert_nil sla(waiting).alert
    waiting.update_columns(status: "postponed")
    assert_equal "waiting", sla(waiting).resolution.state
    waiting.update_columns(status: "open")
    assert_equal "overdue", sla(waiting).resolution.state
  end

  test "no target gives nothing; a done ticket without a reply has no first-response state" do
    normal = sla(ticket(created: 3.hours.ago, priority: "normal"))
    assert_nil normal.first_response
    assert_equal "running", normal.resolution.state
    assert_empty sla(ticket(created: 3.days.ago, priority: "low")).marks
    assert_empty Sla.new(ticket(created: 3.days.ago), targets: {}).marks

    closed = sla(ticket(created: 3.hours.ago, status: "done", done: 1.hour.ago))
    assert_nil closed.first_response
    assert_equal "met", closed.resolution.state
  end

  test "a changed priority is measured against the new targets at once" do
    t = ticket(created: 3.hours.ago, priority: "normal")
    assert_nil sla(t).alert
    t.update_columns(priority: "urgent")
    assert_equal "overdue", sla(t).alert.state
  end

  test "settings keep targets in minutes and refuse what is not a time" do
    setting = AppSetting.current
    setting.sla_hours = { "urgent" => { "first_response" => "0.25", "resolution" => "8" }, "high" => { "first_response" => "1,5" } }
    assert setting.save
    assert_equal 15, setting.sla_minutes("urgent", "first_response")
    assert_equal 480, setting.sla_minutes(:urgent, :resolution)
    assert_equal 90, setting.sla_minutes("high", "first_response")
    assert_nil setting.sla_minutes("low", "resolution")
    assert_equal [ 0.25, 8, 1.5, nil ], [ setting.sla_hours("urgent", "first_response"), setting.sla_hours("urgent", "resolution"),
                                         setting.sla_hours("high", "first_response"), setting.sla_hours("low", "resolution") ]

    [ { "urgent" => { "first_response" => "soon" } }, { "urgent" => { "resolution" => "-1" } },
      { "urgent" => { "resolution" => "9000" } } ].each do |hours|
      setting.sla_hours = hours
      assert_not setting.valid?, hours.to_s
    end
    setting.sla_targets = { "critical" => { "first_response" => 5 } }
    assert_not setting.valid?
    setting.sla_targets = { "urgent" => { "reply" => 5 } }
    assert_not setting.valid?
  end
end
