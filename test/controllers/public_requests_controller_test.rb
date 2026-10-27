require "test_helper"

# Public request page per organization (specs/public-form.md).
class PublicRequestsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    PublicRequestsController::RATE_LIMIT_STORE.clear
    @org = organizations(:acme)
    @org.update!(public_form: true, public_intro: "Bakery help desk.")
  end

  def started(age: 10.seconds, slug: @org.slug)
    travel_to(age.ago) do
      Rails.application.message_verifier(:public_request_form).generate(Time.current.to_i, purpose: slug, expires_in: 1.day)
    end
  end

  def submit(email: "new.person@example.com", **extra)
    post public_request_url(@org.slug), params: {
      started: extra.delete(:started) || started,
      public_request: { name: "New Person", email: email, subject: "Oven broken", description: "It does not heat.", **extra }
    }
  end

  test "the page is off, unknown or on" do
    get public_request_url("globex")
    assert_response :not_found
    get public_request_url("nope")
    assert_response :not_found
    assert_select "h1", "This page is not available"

    get public_request_url(@org.slug)
    assert_response :success
    assert_select "h1", "Contact Acme Bakery support"
    assert_select ".panel__intro", "Bakery help desk."
    assert_select "input[name=website][tabindex='-1']"
    assert_select "input[type=file]", 0
  end

  test "an unknown address gets a requester account, a membership, a ticket and a confirmation" do
    assert_difference -> { User.count } => 1, -> { Ticket.count } => 1 do
      perform_enqueued_jobs { submit }
    end
    assert_redirected_to public_request_thanks_url(@org.slug)
    follow_redirect!
    assert_select "p", /sent a confirmation to new.person@example.com/

    user = User.find_by!(email: "new.person@example.com")
    assert user.requester?
    assert_equal "en", user.locale
    assert_not user.password_chosen?
    assert user.member_of?(@org)
    ticket = Ticket.order(:id).last
    assert_equal [ user, @org, "web_form", "new" ], [ ticket.requester, ticket.organization, ticket.source, ticket.status ]

    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ "new.person@example.com" ] }
    assert_includes mail.subject, "[Stopan ##{ticket.number}]"
    assert_match %r{/magic/\S+\?ticket=#{ticket.number}}, mail.text_part.body.to_s
  end

  test "a known requester gets the ticket and the membership; the answer is the same" do
    assert_no_difference -> { User.count } do
      submit(email: "BORIS@example.com")
    end
    assert_redirected_to public_request_thanks_url(@org.slug)
    assert_equal users(:boris), Ticket.order(:id).last.requester

    users(:carl).memberships.destroy_all if users(:carl).memberships.any?
    submit(email: users(:carl).email)
    assert users(:carl).reload.member_of?(@org)
  end

  test "staff and deactivated addresses create nothing and get the same answer" do
    users(:anna).update!(deactivated_at: Time.current)
    [ users(:agent).email, users(:admin).email, users(:anna).email ].each do |email|
      assert_no_difference -> { Ticket.count } do
        assert_no_enqueued_emails { submit(email: email) }
      end
      assert_redirected_to public_request_thanks_url(@org.slug)
    end
  end

  test "bots: honeypot, a too fresh, old or forged form create nothing" do
    assert_no_difference -> { Ticket.count } do
      post public_request_url(@org.slug), params: { website: "http://spam", started: started,
                                                     public_request: { name: "B", email: "b@example.com", subject: "s", description: "d" } }
      submit(started: started(age: 1.second))
      submit(started: started(age: 2.days))
      submit(started: started(slug: "globex"))
      submit(started: "forged")
    end
    assert_redirected_to public_request_thanks_url(@org.slug)
  end

  test "invalid input re-renders the form" do
    submit(email: "not-an-email")
    assert_response :unprocessable_content
    assert_select ".form-errors"
  end

  test "requests are rate limited per address" do
    5.times { |i| submit(email: "p#{i}@example.com") }
    submit(email: "p9@example.com")
    assert_response :too_many_requests
    assert_select ".flash, [role=alert]", /Too many requests/
  end

  test "signed-in users are sent to the normal form" do
    sign_in users(:anna)
    get public_request_url(@org.slug)
    assert_redirected_to new_ticket_url
  end

  test "the ticket says it came through the web form; the admin page shows the address" do
    submit
    sign_in users(:agent)
    get ticket_url(Ticket.order(:id).last)
    assert_select ".timeline__text", /opened the ticket through the web form/

    sign_in users(:admin)
    get admin_organization_url(@org)
    assert_select "input#public-form-url[value=?]", public_request_url(@org.slug)
  end

  test "allowed senders: listed addresses and domains only; an empty list lets anyone in" do
    @org.update!(public_allowed_senders: "Boss@Partner.example\n@acme.example\n\n@acme.example")
    assert_equal "boss@partner.example\n@acme.example", @org.reload.public_allowed_senders

    assert_no_difference -> { Ticket.count } do
      submit(email: "stranger@example.com")
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /cannot send requests to Acme Bakery/

    assert_difference -> { Ticket.count }, 2 do
      submit(email: "someone@acme.example")
      submit(email: "boss@partner.example")
    end
    assert_no_difference -> { Ticket.count } do
      submit(email: "someone@sub.acme.example")
    end

    @org.update!(public_allowed_senders: "")
    assert_difference -> { Ticket.count } do
      submit(email: "stranger@example.com")
    end
  end

  test "a bad allowed sender entry is refused in the organization form" do
    org = organizations(:acme)
    org.public_allowed_senders = "ok@acme.example\nnot an address\nacme.example"
    assert_not org.valid?
    assert_match(/not an address, acme.example/, org.errors[:public_allowed_senders].first)
  end
end
