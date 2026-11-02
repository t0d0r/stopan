require "test_helper"

# Staff followers and Cc (specs/followers.md).
class TicketFollowerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @ticket = tickets(:printer) # Acme, requested by Anna, assigned to Maria Agent
  end

  test "who may follow: active members of the organization, never the requester" do
    assert @ticket.ticket_followers.build(user: users(:agent_two)).valid?
    assert @ticket.ticket_followers.build(user: users(:boris)).valid?
    assert_not @ticket.ticket_followers.build(user: users(:anna)).valid?
    assert_not @ticket.ticket_followers.build(user: users(:carl)).valid? # Globex only
    assert_not @ticket.ticket_followers.build(user: users(:retired).tap { |u| u.deactivated_at = Time.current }).valid?
  end

  test "follow! writes an internal event; remove_follower! too" do
    follower = @ticket.follow!(users(:agent_two), actor: users(:agent))
    event = @ticket.events.find_by(action: "follower_added")
    assert_equal [ "staff", users(:agent_two).id.to_s, true ], [ event.from_value, event.to_value, event.internal ]
    assert_equal [ users(:agent_two) ], @ticket.staff_followers.to_a

    @ticket.remove_follower!(follower, actor: users(:agent))
    assert_empty @ticket.followers
    assert @ticket.events.exists?(action: "follower_removed", to_value: users(:agent_two).id.to_s)
  end

  test "add_cc! uses an existing requester and adds the membership" do
    follower = @ticket.add_cc!(" CARL@example.com ", actor: users(:agent))
    assert_equal users(:carl), follower.user
    assert users(:carl).member_of?(organizations(:acme))
    assert @ticket.cc?(users(:carl))
    assert_equal [ users(:carl) ], @ticket.cc_users.to_a
    assert @ticket.events.exists?(action: "follower_added", from_value: "cc", to_value: users(:carl).id.to_s)
  end

  test "add_cc! creates a requester for an unknown address, without an email of its own" do
    assert_difference -> { User.count }, 1 do
      @ticket.add_cc!("ivan.petrov@example.net", actor: users(:agent))
    end
    ivan = User.find_by(email: "ivan.petrov@example.net")
    assert_equal [ "requester", "ivan.petrov", false ], [ ivan.role, ivan.name, ivan.password_chosen ]
    assert ivan.member_of?(organizations(:acme))
    assert_empty ActionMailer::Base.deliveries
  end

  test "add_cc! refuses staff, deactivated users, the requester, duplicates and bad addresses" do
    users(:drifter).update!(deactivated_at: Time.current)
    { "petar@example.com" => /staff/, users(:drifter).email => /deactivated/, "anna@example.com" => /requester/,
      "not an address" => /valid/ }.each do |email, message|
      assert_nil @ticket.add_cc!(email, actor: users(:agent)), email
      assert_match message, @ticket.errors.full_messages.to_sentence
      @ticket.errors.clear
    end
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    assert_nil @ticket.add_cc!("boris@example.com", actor: users(:agent))
  end

  test "staff who write on a ticket follow it, silently" do
    @ticket.add_comment(author: users(:agent_two), body: "Looking.", internal: true)
    assert_includes @ticket.followers, users(:agent_two)
    assert_not @ticket.events.exists?(action: "follower_added")
    @ticket.add_comment(author: users(:anna), body: "Thanks.")
    assert_not_includes @ticket.followers, users(:anna)
  end

  test "followers and Cc are notified within their scope; the switch covers Cc" do
    @ticket.follow!(users(:agent_two), actor: users(:agent))
    @ticket.add_cc!("boris@example.com", actor: users(:agent))

    perform_enqueued_jobs { @ticket.add_comment(author: users(:agent), body: "Internal check.", internal: true) }
    assert_equal [ "petar@example.com" ], ActionMailer::Base.deliveries.map { |m| m.to.sole }
    assert_match "you follow this ticket", ActionMailer::Base.deliveries.last.text_part.body.decoded

    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { @ticket.add_comment(author: users(:agent), body: "Please restart it.") }
    assert_equal %w[anna@example.com boris@example.com petar@example.com], ActionMailer::Base.deliveries.map { |m| m.to.sole }.sort
    boris_mail = ActionMailer::Base.deliveries.find { |m| m.to == [ "boris@example.com" ] }
    assert_match "in copy (Cc)", boris_mail.text_part.body.decoded
    assert @ticket.events.exists?(action: "mail_sent", to_value: "boris@example.com")
    assert_not @ticket.events.exists?(action: "mail_sent", to_value: "petar@example.com")

    ActionMailer::Base.deliveries.clear
    @ticket.switch_requester_mail!(false, actor: users(:agent))
    perform_enqueued_jobs { @ticket.add_comment(author: users(:agent), body: "One more.") }
    assert_equal [ "petar@example.com" ], ActionMailer::Base.deliveries.map { |m| m.to.sole }
    assert @ticket.events.exists?(action: "mail_skipped", to_value: "boris@example.com", detail: "switched_off")
    assert Notification.exists?(user: users(:boris), ticket: @ticket)
  end

  test "the mail's To and Cc are suggested, never added" do
    users(:agent_two) # staff address in the headers is left out
    @ticket.update_columns(mail_headers: { "from" => [ "Anna <anna@example.com>" ],
                                           "to" => [ "Support <support@acme.example>", "Ivan <IVAN@example.net>" ],
                                           "cc" => [ "petar@example.com", "boris@example.com", "junk" ] })
    organizations(:acme).update_columns(mailbox_address: "support@acme.example")
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    assert_equal [ "ivan@example.net" ], @ticket.reload.cc_suggestions
    assert_empty @ticket.followers.where(email: "ivan@example.net")
  end

  test "a flush and a user deletion remove the rows" do
    @ticket.add_cc!("new.person@example.net", actor: users(:agent))
    person = User.find_by(email: "new.person@example.net")
    assert_difference -> { TicketFollower.count }, -1 do
      Membership.where(user: person).delete_all
      person.destroy!
    end
    @ticket.follow!(users(:agent_two), actor: users(:agent))
    OrganizationFlush.new(organizations(:acme), actor: users(:admin)).run
    assert_equal 0, TicketFollower.count
  end
end
