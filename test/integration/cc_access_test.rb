require "test_helper"

# What a person in Cc may see and do (specs/followers.md "Visibility").
class CcAccessTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer) # Anna's ticket in Acme
    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    @note = @ticket.add_comment(author: users(:agent), body: "Secret internal remark.", internal: true)
    @ticket.add_comment(author: users(:agent), body: "Public answer.")
    sign_in users(:boris)
  end

  test "a Cc sees the public part, in My tickets with a tag, and no internal note" do
    get ticket_url(@ticket)
    assert_response :success
    assert_match "Public answer.", response.body
    assert_no_match "Secret internal remark.", response.body
    assert_no_match "added", css_select(".timeline__text").map(&:text).join(" ")

    get tickets_url(view: "all")
    assert_select "a[href=?]", ticket_path(@ticket)
    assert_select ".cc-tag", "Cc"
  end

  test "a Cc replies, but cannot mark done, edit the request or share" do
    post ticket_comments_url(@ticket), params: { comment: { body: "Me too.", internal: "1" } }
    comment = @ticket.comments.last
    assert_equal [ users(:boris), false ], [ comment.author, comment.internal ]

    policy = TicketPolicy.new(users(:boris), @ticket.reload)
    assert policy.reply?
    assert policy.edit_comment?(comment)
    assert_not policy.resolve?
    assert_not policy.edit_description?
    assert_not policy.share?
    assert_not policy.update?
  end

  test "removed from Cc or from the organization, the access ends" do
    @ticket.remove_follower!(@ticket.ticket_followers.find_by(user: users(:boris)), actor: users(:agent))
    get ticket_url(@ticket)
    assert_response :not_found

    @ticket.add_cc!("boris@example.com", actor: users(:agent))
    Membership.create!(user: users(:boris), organization: organizations(:globex))
    memberships(:boris_acme).destroy
    # A 404 ends the test sign-in, so sign in again.
    sign_in users(:boris)
    get ticket_url(@ticket)
    assert_response :not_found
  end

  test "a Cc's email reply becomes a public reply" do
    raw = <<~MAIL
      From: Boris <boris@example.com>
      To: support@acme.example
      Subject: Re: [Stopan ##{@ticket.number}] Receipt printer prints blank pages
      Content-Type: text/plain; charset=UTF-8

      Same here at till 3.
    MAIL
    assert_equal :reply, MailboxMessage.new(organizations(:acme), raw).process
    comment = @ticket.comments.last
    assert_equal [ users(:boris), false, "email" ], [ comment.author, comment.internal, comment.source ]
  end
end
