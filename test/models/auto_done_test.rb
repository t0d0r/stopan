require "test_helper"

# Pending tickets without activity are marked done (specs/board.md
# "Automatic done").
class AutoDoneTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper
  include TicketsHelper

  setup do
    @ticket = tickets(:printer) # Acme, requested by Anna
    @ticket.update_columns(status: "pending", updated_at: 15.days.ago)
  end

  test "off by default; only pending tickets past the period are done, without an actor, and the requester is emailed" do
    assert_equal 0, AppSetting.current.auto_done_days
    assert_equal 0, AutoDone.run
    assert_equal "pending", @ticket.reload.status

    AppSetting.current.update!(auto_done_days: 14)
    tickets(:email_account).update_columns(status: "open", updated_at: 90.days.ago)
    recent = Ticket.create!(subject: "Recent", description: "x", requester: users(:anna), organization: organizations(:acme),
                            actor: users(:agent))
    recent.update_columns(status: "pending", updated_at: 13.days.ago)

    done = nil
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { done = AutoDone.run }
    assert_equal 1, done
    assert_equal [ "done", "open", "pending" ], [ @ticket, tickets(:email_account), recent ].map { it.reload.status }
    assert @ticket.done_at
    event = @ticket.events.where(action: "status_changed").last
    assert_equal [ nil, "pending", "done", false ], [ event.actor, event.from_value, event.to_value, event.internal ]
    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ users(:anna).email ] }
    assert mail, "the requester is told"
    assert_match "opens again", mail.text_part.body.decoded

    @ticket.add_comment(author: users(:anna), body: "Still broken.")
    assert_equal "open", @ticket.reload.status
  end

  test "the setting takes 0 to 3650 whole days" do
    setting = AppSetting.current
    assert setting.update(auto_done_days: 3650)
    assert_not setting.update(auto_done_days: -1)
    assert_not setting.update(auto_done_days: 3651)
  end

  test "days left count down, and the shorter period shows on the ticket" do
    assert_nil AutoDone.days_left(@ticket, 0)
    assert_equal 5, AutoDone.days_left(@ticket, 20)
    assert_equal 0, AutoDone.days_left(@ticket, 10)
    @ticket.status = "open"
    assert_nil AutoDone.days_left(@ticket, 20)
    @ticket.status = "pending"

    AppSetting.current.update!(auto_postpone_days: 18, auto_done_days: 20)
    assert_match "Moves to Not now in 3 days", postpone_note(@ticket)
    assert postpone_stamp(@ticket)

    @postpone_days = @auto_done_days = nil
    AppSetting.current.update!(auto_postpone_days: 30, auto_done_days: 20)
    assert_match "Marked done in 5 days without activity.", postpone_note(@ticket)
    assert_nil postpone_stamp(@ticket)

    @postpone_days = @auto_done_days = nil
    AppSetting.current.update!(auto_postpone_days: 0, auto_done_days: 15)
    assert_match "Marked done today without activity.", postpone_note(@ticket)
  end
end
