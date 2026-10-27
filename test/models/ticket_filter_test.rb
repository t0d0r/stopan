require "test_helper"

class TicketFilterTest < ActiveSupport::TestCase
  def numbers(user, params = {})
    TicketFilter.new(user, ActionController::Parameters.new(params)).tickets.map(&:number)
  end

  test "staff views" do
    agent = users(:agent)
    assert_equal [ 1003, 1002, 1001 ], numbers(agent)
    assert_equal [ 1001 ], numbers(agent, view: "mine")
    assert_equal [ 1002 ], numbers(agent, view: "unassigned")
    assert_equal [ 1003 ], numbers(agent, view: "pending")
    assert_equal [ 1004 ], numbers(agent, view: "solved")
    assert_equal 4, numbers(agent, view: "all").size
    assert_equal({ "unsolved" => 3, "mine" => 1, "unassigned" => 1, "pending" => 1, "postponed" => 0, "solved" => 1, "all" => 4 },
                 TicketFilter.new(agent, {}).counts)
  end

  test "filters narrow the view" do
    agent = users(:agent)
    assert_equal [ 1002 ], numbers(agent, status: "new")
    assert_equal [ 1003 ], numbers(agent, priority: "urgent")
    assert_equal [ 1002 ], numbers(agent, assignee: "none")
    assert_equal [ 1001 ], numbers(agent, assignee: "me")
    assert_equal [ 1003 ], numbers(agent, assignee: users(:agent_two).id.to_s)
    assert_equal [ 1003 ], numbers(agent, organization: organizations(:globex).id.to_s)
  end

  test "unknown values are ignored" do
    agent = users(:agent)
    filter = TicketFilter.new(agent, { view: "everything", status: "lost", priority: "x", assignee: users(:anna).id.to_s,
                                       organization: "999999", sort: "random", page: "-3" })
    assert_equal "unsolved", filter.view
    assert_not filter.filtered?
    assert_equal "updated", filter.sort
    assert_equal 1, filter.page
  end

  test "search by text or number, with Unicode case folding and escaped wildcards" do
    agent = users(:agent)
    assert_equal [ 1001 ], numbers(agent, q: "PRINTER")
    assert_equal [ 1002 ], numbers(agent, q: "#1002")
    assert_equal [ 1003 ], numbers(agent, view: "all", q: "1003")
    assert_empty numbers(agent, q: "%")
    tickets(:email_account).update_columns(subject: "Принтерът не работи")
    assert_equal [ 1002 ], numbers(agent, q: "принтер")
  end

  test "sort by priority puts urgent first" do
    assert_equal [ 1003, 1002, 1001 ], numbers(users(:agent), sort: "priority")
    assert_equal [ 1003, 1002, 1001 ], numbers(users(:agent), sort: "created")
  end

  test "requesters get their own tickets and requester views only" do
    anna = users(:anna)
    assert_equal [ 1001 ], numbers(anna)
    assert_equal [ 1004 ], numbers(anna, view: "solved")
    assert_equal [ 1001, 1004 ], numbers(anna, view: "all").sort
    assert_equal "open", TicketFilter.new(anna, { view: "unassigned" }).view
    # Staff-only filters do not apply to requesters.
    assert_equal [ 1001 ], numbers(anna, assignee: "none", organization: organizations(:globex).id.to_s)
    assert_empty numbers(anna, q: "VPN")
  end

  test "pagination" do
    agent = users(:agent)
    30.times do |i|
      Ticket.create!(subject: "Bulk #{i}", description: "x", requester: users(:carl), organization: organizations(:globex),
                     actor: agent)
    end
    filter = TicketFilter.new(agent, { view: "all" })
    assert_equal 25, filter.tickets.size
    assert_equal 2, filter.total_pages
    assert_equal [ 1, 25 ], [ filter.first_index, filter.last_index ]
    second = TicketFilter.new(agent, { view: "all", page: "2" })
    assert_equal 9, second.tickets.size
    assert_equal({ view: "all", page: 3 }, second.params_with(page: 3))
  end

  test "postponed tickets have their own view and stay in the requester's Open tab" do
    tickets(:printer).update_columns(status: "postponed")
    assert_equal [ 1001 ], numbers(users(:agent), view: "postponed")
    assert_not_includes numbers(users(:agent), view: "unsolved"), 1001
    assert_includes numbers(users(:anna), view: "open"), 1001
  end
end
