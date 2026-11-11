require "test_helper"

# Leaving a ticket from the link in an email (specs/followers.md "Leaving").
class LeaveLinksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @ticket = tickets(:printer) # Acme, requested by Anna, assigned to Maria Agent
    @ticket.follow!(users(:agent_two), actor: users(:agent))
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    perform_enqueued_jobs { @ticket.add_comment(author: users(:agent), body: "Please restart it.") }
  end

  def mail_to(email)
    ActionMailer::Base.deliveries.find { |mail| mail.to == [ email ] }
  end

  # The path of the link in both parts of the email.
  def leave_path(email)
    mail = mail_to(email)
    url = mail.text_part.body.decoded[%r{https?://\S+/leave/\S+}]
    assert url, "no leave link in the email to #{email}"
    assert_includes mail.html_part.body.decoded, %(href="#{url}")
    URI(url).path
  end

  test "the link is in the emails of followers and Cc only" do
    assert_match "To leave the copy (Cc) and stop these emails:", mail_to("boris@example.com").text_part.body.decoded
    assert_match "To stop following this ticket:", mail_to("petar@example.com").text_part.body.decoded
    assert_no_match "/leave/", mail_to("anna@example.com").text_part.body.decoded
    assert_no_match "/leave/", mail_to("anna@example.com").html_part.body.decoded
  end

  test "opening the link changes nothing; the button takes the person in Cc off" do
    path = leave_path("boris@example.com")
    get path
    assert_response :success
    assert_select "h2", "Ticket #{@ticket.reference}"
    assert_select "form[action=?][method=post] button", path, text: /Leave Cc/
    assert_not_includes response.body, @ticket.subject
    assert @ticket.cc?(users(:boris))

    post path
    assert_response :success
    assert_select "h2", "You are no longer in copy on #{@ticket.reference}."
    assert_not @ticket.cc?(users(:boris))
    event = @ticket.events.where(action: "follower_removed").last
    assert_equal [ users(:boris).id, "cc", users(:boris).id.to_s, true ], [ event.actor_id, event.from_value, event.to_value, event.internal ]

    get path
    assert_response :not_found
    assert_select "h2", "This link is no longer valid"
    post path
    assert_response :not_found

    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select ".timeline__text", "Boris Requester left Cc"
  end

  test "a follower stops following; a token of another row or a made-up one is refused" do
    path = leave_path("petar@example.com")
    get path
    assert_select "form button", text: /Stop following/
    post path
    assert_select "h2", "You no longer follow #{@ticket.reference}."
    assert_not @ticket.ticket_followers.exists?(user: users(:agent_two))

    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select ".timeline__text", "Petar Agent stopped following"

    get leave_link_url("made-up")
    assert_response :not_found
    get leave_link_url(users(:boris).generate_token_for(:magic_sign_in))
    assert_response :not_found
  end

  test "the page speaks the language of the person's emails" do
    users(:boris).update!(language: "bg")
    get leave_path("boris@example.com")
    assert_select "button", text: /Излез от копието/
  end
end
