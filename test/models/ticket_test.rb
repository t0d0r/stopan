require "test_helper"

class TicketTest < ActiveSupport::TestCase
  def new_ticket(**attributes)
    Ticket.new({ subject: "Coffee machine is broken", description: "It leaks.", requester: users(:anna),
                 organization: organizations(:acme), actor: users(:anna) }.merge(attributes))
  end

  test "numbers start at 1001 and count up" do
    assert_equal 1005, Ticket.next_number
    ticket = new_ticket
    ticket.save!
    assert_equal 1005, ticket.number
    assert_equal "#1005", ticket.reference
    assert_equal "1005", ticket.to_param
  end

  test "the first ticket is 1001" do
    TicketEvent.delete_all
    Comment.delete_all
    Ticket.delete_all
    assert_equal 1001, Ticket.next_number
  end

  test "defaults and required fields" do
    ticket = new_ticket
    assert ticket.valid?
    assert_equal "new", ticket.status
    assert_equal "normal", ticket.priority

    ticket = new_ticket(subject: " ", description: "")
    assert_not ticket.valid?
    assert ticket.errors.of_kind?(:subject, :blank)
    assert ticket.errors.of_kind?(:description, :blank)
    assert_not new_ticket(subject: "x" * 201).valid?
    assert_not new_ticket(priority: "whenever").valid?
  end

  test "the requester must belong to the organization" do
    ticket = new_ticket(organization: organizations(:globex))
    assert_not ticket.valid?
    assert ticket.errors.of_kind?(:requester, :not_a_member)
  end

  test "the assignee must be active staff" do
    assert new_ticket(assignee: users(:agent)).valid?
    assert new_ticket(assignee: users(:admin)).valid?
    assert new_ticket(assignee: users(:boris)).invalid?
    ticket = new_ticket(assignee: users(:retired))
    assert ticket.invalid?
    assert ticket.errors.of_kind?(:assignee, :not_staff)
  end

  test "creating writes a created event" do
    ticket = new_ticket
    ticket.save!
    assert_equal [ [ "created", users(:anna).id, false ] ], ticket.events.map { |e| [ e.action, e.actor_id, e.internal ] }
  end

  test "allowed and refused status transitions" do
    ticket = tickets(:email_account) # new
    Ticket::TRANSITIONS.each do |from, targets|
      (Ticket::STATUSES - [ from ]).each do |to|
        ticket.reload.update_columns(status: from)
        ticket.status = to
        assert_equal targets.include?(to), ticket.valid?, "#{from} -> #{to}"
      end
    end
  end

  test "nothing goes back to new and closed only reopens" do
    assert_not Ticket::TRANSITIONS.values.flatten.include?("new")
    assert_equal %w[open], Ticket::TRANSITIONS["closed"]
  end

  test "changes write one event per field with the right visibility" do
    ticket = tickets(:email_account)
    assert ticket.apply_changes({ status: "open", priority: "urgent", assignee_id: users(:agent).id }, actor: users(:agent))
    events = ticket.events.where.not(action: "created").map { |e| [ e.action, e.from_value, e.to_value, e.internal ] }
    assert_equal [ [ "status_changed", "new", "open", false ],
                   [ "priority_changed", "high", "urgent", true ],
                   [ "assignee_changed", nil, users(:agent).id.to_s, true ] ], events
    assert ticket.events.all? { |e| e.actor == users(:agent) }
  end

  test "an invalid change saves nothing" do
    ticket = tickets(:old_question) # closed
    assert_no_difference "TicketEvent.count" do
      assert_not ticket.apply_changes({ status: "pending", priority: "high" }, actor: users(:agent))
    end
    assert_equal "low", ticket.reload.priority
  end

  test "status times" do
    ticket = tickets(:printer)
    ticket.apply_changes!({ status: "resolved" }, actor: users(:agent))
    assert ticket.resolved_at
    ticket.apply_changes!({ status: "closed" }, actor: users(:agent))
    assert ticket.closed_at
    ticket.apply_changes!({ status: "open" }, actor: users(:agent))
    assert_nil ticket.resolved_at
    assert_nil ticket.closed_at
  end

  test "a staff reply opens a new ticket" do
    ticket = tickets(:email_account)
    comment = ticket.add_comment(author: users(:agent), body: "On it.")
    assert comment.persisted?
    assert_equal "open", ticket.reload.status
    assert_equal %w[replied status_changed], ticket.events.last(2).map(&:action)
  end

  test "a staff reply can choose the status" do
    ticket = tickets(:email_account)
    ticket.add_comment(author: users(:agent), body: "Done, password sent separately.", status: "resolved")
    assert_equal "resolved", ticket.reload.status
  end

  test "an invalid chosen status keeps the comment out too" do
    ticket = tickets(:old_question)
    assert_no_difference "Comment.count" do
      comment = ticket.add_comment(author: users(:agent), body: "note", internal: true, status: "pending")
      assert_not comment.persisted?
      assert_predicate comment.errors[:base], :any?
    end
    assert_equal "closed", ticket.reload.status
  end

  test "a requester reply reopens pending and resolved tickets only" do
    vpn = tickets(:vpn)
    vpn.update_columns(status: "pending")
    vpn.add_comment(author: users(:carl), body: "Still broken.")
    assert_equal "open", vpn.reload.status

    vpn.update_columns(status: "resolved")
    vpn.add_comment(author: users(:carl), body: "Broken again.")
    assert_equal "open", vpn.reload.status

    ticket = tickets(:email_account)
    ticket.add_comment(author: users(:boris), body: "Any news?")
    assert_equal "new", ticket.reload.status
  end

  test "internal notes do not change the status" do
    ticket = tickets(:email_account)
    ticket.add_comment(author: users(:agent), body: "Checking licences.", internal: true)
    assert_equal "new", ticket.reload.status
  end

  test "closed tickets take internal notes but no public replies" do
    ticket = tickets(:old_question)
    assert_not ticket.add_comment(author: users(:agent), body: "Hello?").persisted?
    assert_not ticket.add_comment(author: users(:anna), body: "Hello?").persisted?
    assert ticket.add_comment(author: users(:agent), body: "For the record.", internal: true).persisted?
  end

  test "attachment limits" do
    assert new_ticket(files: [ upload ]).valid?

    ticket = new_ticket(files: Array.new(Attachable::MAX_FILES + 1) { upload })
    assert ticket.invalid?
    assert ticket.errors.of_kind?(:files, :too_many)

    ticket = new_ticket(files: [ upload("page.html", "text/html") ])
    assert ticket.invalid?
    assert ticket.errors.of_kind?(:files, :type_not_allowed)

    big = new_ticket
    big.files.attach(io: StringIO.new("a" * (Attachable::MAX_SIZE + 1)), filename: "big.txt", content_type: "text/plain")
    assert big.invalid?
    assert big.errors.of_kind?(:files, :too_big)
  end

  test "visible_to: staff see all, requesters every ticket of their organizations" do
    assert_equal Ticket.count, Ticket.visible_to(users(:agent)).count
    assert_equal Ticket.count, Ticket.visible_to(users(:admin)).count
    assert_equal %w[1001 1002 1004], Ticket.visible_to(users(:anna)).order(:number).map(&:to_param)
    assert_equal [ 1001, 1002, 1004 ], Ticket.visible_to(users(:boris)).order(:number).pluck(:number)
    assert_equal [ 1003 ], Ticket.visible_to(users(:carl)).pluck(:number)
    assert_empty Ticket.visible_to(users(:drifter))
    assert_empty Ticket.visible_to(nil)
  end

  test "a requester removed from the organization loses access" do
    memberships(:anna_acme).destroy
    assert_empty Ticket.visible_to(users(:anna).reload)
  end
end
