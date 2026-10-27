require "test_helper"

class TicketPolicyTest < ActiveSupport::TestCase
  def policy(user, ticket)
    TicketPolicy.new(users(user), tickets(ticket))
  end

  test "requesters on their own open ticket" do
    p = policy(:anna, :printer)
    assert p.show?
    assert p.reply?
    assert_not p.note?
    assert_not p.update?
    assert p.resolve?
    assert_not p.see_internal?
  end

  test "requesters read colleagues' tickets but do not work on them" do
    assert policy(:boris, :printer).show?
    assert_not policy(:boris, :printer).reply?
    assert_not policy(:boris, :printer).resolve?
    assert_not policy(:boris, :printer).share?
    assert_not policy(:boris, :printer).edit_description?
    assert_not policy(:carl, :printer).show?
    assert_not policy(:carl, :printer).resolve?
  end

  test "closed tickets take no replies but staff notes" do
    assert_not policy(:anna, :old_question).reply?
    assert_not policy(:anna, :old_question).resolve?
    assert_not policy(:agent, :old_question).reply?
    assert policy(:agent, :old_question).note?
    assert policy(:agent, :old_question).comment?
  end

  test "staff can do everything on tickets" do
    p = policy(:agent, :vpn)
    assert p.show?
    assert p.reply?
    assert p.note?
    assert p.update?
    assert p.see_internal?
  end

  test "create needs a membership for requesters" do
    assert TicketPolicy.new(users(:anna), Ticket.new).create?
    assert_not TicketPolicy.new(users(:drifter), Ticket.new).create?
    assert TicketPolicy.new(users(:agent), Ticket.new).create?
  end

  test "a requester who left the organization cannot reply" do
    memberships(:anna_acme).destroy
    assert_not policy(:anna, :printer).reply?
  end
end
