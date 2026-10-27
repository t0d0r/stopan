require "test_helper"

# Automatic postponing after inactivity (specs/board.md).
class AutoPostponeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "inactive new, open and pending tickets move to Not now without an actor or email to the requester" do
    AppSetting.current.update!(auto_postpone_days: 30)
    tickets(:printer).update_columns(updated_at: 31.days.ago)
    tickets(:email_account).update_columns(updated_at: 29.days.ago)
    tickets(:old_question).update_columns(updated_at: 90.days.ago)

    moved = nil
    perform_enqueued_jobs { moved = AutoPostpone.run }
    assert_equal 1, moved
    assert_equal "postponed", tickets(:printer).reload.status
    assert_not_equal "postponed", tickets(:email_account).reload.status
    assert_equal "done", tickets(:old_question).reload.status
    event = tickets(:printer).events.where(action: "status_changed").last
    assert_nil event.actor
    assert_equal "postponed", event.to_value
    assert_not ActionMailer::Base.deliveries.any? { |m| m.to == [ users(:anna).email ] }
  end

  test "0 turns it off; days left count down" do
    AppSetting.current.update!(auto_postpone_days: 0)
    tickets(:printer).update_columns(updated_at: 400.days.ago)
    assert_equal 0, AutoPostpone.run
    assert_nil AutoPostpone.days_left(tickets(:printer).reload, 0)

    tickets(:printer).update_columns(updated_at: 27.days.ago)
    assert_equal 3, AutoPostpone.days_left(tickets(:printer).reload, 30)
    tickets(:printer).update_columns(updated_at: 31.days.ago)
    assert_equal 0, AutoPostpone.days_left(tickets(:printer).reload, 30)
  end
end
