require "test_helper"

# Board stages (specs/board.md "Stages").
class StageTest < ActiveSupport::TestCase
  setup do
    @investigating = Stage.create!(status: "open", name: "Investigating", color: "pink")
    @qa = Stage.create!(status: "open", name: "QA to confirm", color: "green")
  end

  test "stages order within their status and swap places" do
    assert_equal [ @investigating, @qa ], Stage.where(status: "open").ordered.to_a
    @qa.move(-1)
    assert_equal [ @qa, @investigating ], Stage.where(status: "open").ordered.to_a
    assert_not Stage.new(status: "open", name: "qa to confirm", color: "gray").valid?
    assert_not Stage.new(status: "nope", name: "X", color: "gray").valid?
  end

  test "a stage change is an internal event with names; a status change leaves the stage" do
    ticket = tickets(:printer)
    ticket.apply_changes!({ stage: @investigating }, actor: users(:agent))
    event = ticket.events.where(action: "stage_changed").last
    assert_equal [ nil, "Investigating", true ], [ event.from_value, event.to_value, event.internal ]

    ticket.apply_changes!({ status: "pending" }, actor: users(:agent))
    assert_nil ticket.reload.stage
    assert_equal [ "Investigating", nil ], ticket.events.where(action: "stage_changed").last.slice(:from_value, :to_value).values

    # A stage of another status does not stick.
    ticket.apply_changes({ stage: @qa }, actor: users(:agent))
    assert_nil ticket.reload.stage
  end

  test "deleting a stage puts its tickets back in the plain status" do
    ticket = tickets(:printer)
    ticket.apply_changes!({ stage: @qa }, actor: users(:agent))
    @qa.destroy
    assert_nil ticket.reload.stage_id
    assert_equal "open", ticket.status
  end
end
