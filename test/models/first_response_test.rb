require "test_helper"

# specs/sla.md "The first response is remembered"
class FirstResponseTest < ActiveSupport::TestCase
  test "only the first public reply by staff sets it, once" do
    ticket = Ticket.create!(subject: "T", description: "x", requester: users(:anna), organization: organizations(:acme), actor: users(:anna))
    assert_nil ticket.first_response_at

    ticket.add_comment(author: users(:anna), body: "Any news?")
    ticket.add_comment(author: users(:agent), body: "Checking the logs", internal: true)
    assert_nil ticket.reload.first_response_at

    first = ticket.add_comment(author: users(:agent), body: "On it.")
    assert_equal first.created_at.to_i, ticket.reload.first_response_at.to_i

    travel 2.hours do
      ticket.add_comment(author: users(:admin), body: "Fixed.")
      assert_equal first.created_at.to_i, ticket.reload.first_response_at.to_i
    end
  end
end
