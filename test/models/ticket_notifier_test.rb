require "test_helper"

# Who is emailed about what (specs/notifications.md). The jobs are
# performed, so these tests also go through TicketMailer's own checks.
class TicketNotifierTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  # { email => subject } of the emails sent while the block runs.
  def mails
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { yield }
    ActionMailer::Base.deliveries.to_h { |mail| [ mail.to.sole, mail.subject ] }
  end

  def body_of(email)
    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ email ] }
    mail.html_part.body.decoded + mail.text_part.body.decoded
  end

  def open_ticket(actor:, **attributes)
    Ticket.create!({ subject: "Scale shows wrong weight", description: "Off by 20 g.", requester: users(:anna),
                     organization: organizations(:acme), actor: actor }.merge(attributes))
  end

  test "a requester opening a ticket emails the subscribers, not the requester" do
    users(:agent_two).update!(notify_new_tickets: true)
    users(:retired).update_columns(notify_new_tickets: true)

    sent = mails { open_ticket(actor: users(:anna)) }

    assert_equal [ "petar@example.com" ], sent.keys
    assert_match(/\A\[Stopan #1005\] New ticket: Scale shows wrong weight\z/, sent["petar@example.com"])
    assert_includes body_of("petar@example.com"), "Off by 20 g."
  end

  test "staff opening a ticket for a requester emails the requester and the assignee" do
    sent = mails { open_ticket(actor: users(:agent), assignee: users(:agent_two)) }

    assert_equal %w[anna@example.com petar@example.com], sent.keys.sort
    assert_includes body_of("anna@example.com"), "Maria Agent opened ticket #1005 for you."
    assert_includes body_of("petar@example.com"), "assigned to you"
  end

  test "a staff reply with a status change is one email per person" do
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)

    sent = mails { ticket.add_comment(author: users(:agent), body: "Please try a new roll.", status: "pending") }

    assert_equal %w[anna@example.com petar@example.com], sent.keys.sort
    assert_equal "[Stopan #1001] New reply: Receipt printer prints blank pages", sent["anna@example.com"]
    body = body_of("anna@example.com")
    assert_includes body, "Please try a new roll."
    assert_includes body, "The status is now Pending."
    assert_includes body, "waiting for your answer"
  end

  test "nobody is emailed about their own action" do
    sent = mails { tickets(:printer).add_comment(author: users(:anna), body: "It still happens.") }

    assert_equal [ "maria@example.com" ], sent.keys
  end

  test "internal notes reach the assignee only and never a requester" do
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)

    sent = mails { ticket.add_comment(author: users(:agent), body: "SECRET supplier price", internal: true) }

    assert_equal [ "petar@example.com" ], sent.keys
    assert_match(/Internal note/, sent["petar@example.com"])
  end

  test "an internal note that changes the status tells the requester only the status" do
    sent = mails do
      tickets(:printer).add_comment(author: users(:agent_two), body: "SECRET workaround", internal: true, status: "done")
    end

    assert_equal "[Stopan #1001] Status changed: Receipt printer prints blank pages", sent["anna@example.com"]
    body = body_of("anna@example.com")
    assert_not_includes body, "SECRET"
    assert_includes body, "from In progress to Done"
    assert_includes body, "reply on the ticket page and the ticket opens again"
    assert_match(/Internal note/, sent["maria@example.com"])
  end

  test "assigning emails the new assignee; priority alone and unassigning email nobody" do
    ticket = tickets(:email_account)
    assert_equal({ "petar@example.com" => "[Stopan #1002] Assigned to you: New staff member needs an email account" },
                 mails { ticket.apply_changes!({ assignee_id: users(:agent_two).id }, actor: users(:agent)) })
    assert_empty mails { ticket.apply_changes!({ priority: "urgent" }, actor: users(:agent)) }
    assert_empty mails { users(:agent_two).release_assigned_tickets!(users(:admin)) }
  end

  test "triage from new to open emails nobody" do
    assert_empty mails { tickets(:email_account).apply_changes!({ status: "open" }, actor: users(:agent)) }
  end

  test "a requester marking a ticket done tells the assignee" do
    sent = mails { tickets(:printer).apply_changes!({ status: "done" }, actor: users(:anna)) }

    assert_equal [ "maria@example.com" ], sent.keys
    assert_includes body_of("maria@example.com"), "Anna Requester changed the status of ticket #1001 from In progress to Done."
  end

  test "deactivated users and requesters who left the organization get nothing" do
    memberships(:anna_acme).destroy!
    users(:agent).update_columns(deactivated_at: Time.current)

    assert_empty mails { tickets(:printer).add_comment(author: users(:agent_two), body: "Any news?") }
  end

  test "losing access after queueing stops the email at sending time" do
    tickets(:printer).add_comment(author: users(:agent), body: "We ordered a new printer.")
    assert_enqueued_emails 1
    memberships(:anna_acme).destroy!

    perform_enqueued_jobs
    assert_empty ActionMailer::Base.deliveries
  end

  test "a rolled back action sends nothing" do
    sent = mails do
      Ticket.transaction do
        tickets(:printer).add_comment(author: users(:agent), body: "Never sent.")
        raise ActiveRecord::Rollback
      end
    end
    assert_empty sent
  end

  test "emails use the recipient's language and escape user text" do
    users(:anna).update_columns(locale: "bg")
    sent = mails { tickets(:printer).add_comment(author: users(:agent), body: "Try <b>this</b> & that") }

    assert_equal "[Stopan #1001] Нов отговор: Receipt printer prints blank pages", sent["anna@example.com"]
    mail = ActionMailer::Base.deliveries.sole
    assert_includes mail.html_part.body.decoded, "Try &lt;b&gt;this&lt;/b&gt; &amp; that"
    assert_includes mail.text_part.body.decoded, "Try <b>this</b> & that"
    assert_includes mail.text_part.body.decoded, "Maria Agent отговори по заявка #1001."
    assert_includes mail.text_part.body.decoded, "http://example.com/tickets/1001"
    assert_equal "<ticket-1001@example.com>", mail["References"].value
  end

  test "the organization's email language reaches its requesters, not staff" do
    organizations(:acme).update!(mail_locale: "de")
    users(:anna).update_columns(locale: "bg")
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)

    sent = mails { ticket.add_comment(author: users(:agent), body: "Try a new roll.") }

    assert_equal "[Stopan #1001] Neue Antwort: Receipt printer prints blank pages", sent["anna@example.com"]
    assert_equal "[Stopan #1001] New reply: Receipt printer prints blank pages", sent["petar@example.com"]

    users(:anna).choose_language!("bg")
    sent = mails { ticket.add_comment(author: users(:agent), body: "Any luck?") }
    assert_equal "[Stopan #1001] Нов отговор: Receipt printer prints blank pages", sent["anna@example.com"]
  end

  test "names are escaped in HTML and plain in text" do
    users(:agent).update_columns(name: "Maria <Ops> & Co")
    mails { tickets(:printer).add_comment(author: users(:agent), body: "Done.") }

    mail = ActionMailer::Base.deliveries.sole
    assert_includes mail.html_part.body.decoded, "Maria &lt;Ops&gt; &amp; Co replied"
    assert_includes mail.text_part.body.decoded, "Maria <Ops> & Co replied"
  end

  test "a new ticket reaches the staff members in the app, without email, and never other requesters" do
    users(:agent_two).update!(notify_new_tickets: false)
    sent = mails { open_ticket(actor: users(:anna)) }
    ticket = Ticket.order(:id).last
    assert_not sent.key?(users(:agent_two).email)
    note = Notification.find_by!(user: users(:agent_two), ticket: ticket)
    assert_equal [ "created", users(:anna) ], [ note.kind, note.actor ]
    assert_not Notification.exists?(user: users(:anna), ticket: ticket)
    # Requesters see only their own tickets (specs/roles.md).
    assert_not Notification.exists?(user: users(:boris), ticket: ticket)
    assert_not Notification.exists?(user: users(:carl), ticket: ticket)

    perform_enqueued_jobs { ticket.add_comment(author: users(:agent), body: "On it") }
    assert_not Notification.exists?(user: users(:boris), ticket: ticket)
  end

  test "postponing reaches the requester in the app only" do
    ticket = tickets(:printer)
    sent = mails { ticket.apply_changes!({ status: "postponed" }, actor: users(:agent)) }
    assert_not sent.key?(users(:anna).email)
    note = Notification.where(user: users(:anna), ticket: ticket).last
    assert_equal [ "status_changed", "postponed" ], [ note.kind, note.status ]

    mails { ticket.add_comment(author: users(:anna), body: "Any news?") }
    assert_equal "open", ticket.reload.status
  end

  # specs/sharing.md "Link in the requester's emails".
  test "the requester of a ticket from email gets the shared page with their address as password" do
    ticket = tickets(:printer)
    ticket.update_columns(source: "email", assignee_id: users(:agent_two).id)

    mails { ticket.add_comment(author: users(:agent), body: "Please try a new roll.") }

    ticket.reload
    assert ticket.shared?
    assert ticket.authenticate_share_password("anna@example.com")
    event = ticket.events.find_by!(action: "shared")
    assert_nil event.actor
    assert event.internal?
    requester = body_of("anna@example.com")
    assert_includes requester, "/s/#{ticket.share_token}"
    assert_not_includes requester, "/tickets/1001"
    assert_includes requester, "Read ticket #1001 online, without signing in"
    assert_includes requester, "The password is your email address"
    staff = body_of("petar@example.com")
    assert_includes staff, "/tickets/1001"
    assert_not_includes staff, "/s/"

    token = ticket.share_token
    mails { ticket.add_comment(author: users(:agent), body: "Any luck?") }
    assert_equal token, ticket.reload.share_token, "the link is made once"
    assert_includes body_of("anna@example.com"), "/s/#{token}"
  end

  test "an existing link is kept: an open one is given, one with another password is not" do
    ticket = tickets(:printer)
    ticket.update_columns(source: "email")
    ticket.share!(actor: users(:agent))
    token = ticket.share_token

    mails { ticket.add_comment(author: users(:agent), body: "Open link") }
    assert_includes body_of("anna@example.com"), "/s/#{token}"
    assert_not_includes body_of("anna@example.com"), "The password is your email address"

    ticket.share!(actor: users(:agent), password: "staff-secret")
    token = ticket.share_token
    mails { ticket.add_comment(author: users(:agent), body: "Staff password") }
    assert_equal token, ticket.reload.share_token
    assert_includes body_of("anna@example.com"), "/tickets/1001"
    assert_not_includes body_of("anna@example.com"), "/s/"
  end

  test "requesters of tickets from the app keep the ticket page and nothing is shared" do
    ticket = tickets(:printer)
    mails { ticket.add_comment(author: users(:agent), body: "Please try a new roll.") }
    assert_not ticket.reload.shared?
    assert_includes body_of("anna@example.com"), "/tickets/1001"
  end

  test "with the organization's mailbox on, the email says to answer by replying to it" do
    organizations(:acme).update_columns(imap_enabled: true, mailbox_address: "help@acme.example")
    ticket = tickets(:printer)
    ticket.update_columns(assignee_id: users(:agent_two).id)

    mails { ticket.add_comment(author: users(:agent), body: "Please try a new roll.", status: "pending") }

    requester = body_of("anna@example.com")
    assert_includes requester, "The service desk is waiting for your answer. Reply to this email."
    assert_includes requester, "To answer, reply to this email; your reply is added to the ticket."
    assert_not_includes requester, "Replies to this email are not read"
    assert_includes body_of("petar@example.com"), "added to the ticket as a public reply that the requester sees"
    assert_equal [ "help@acme.example" ], ActionMailer::Base.deliveries.first.reply_to

    organizations(:acme).update_columns(imap_enabled: false)
    mails { ticket.add_comment(author: users(:agent), body: "Done?", status: "done") }
    requester = body_of("anna@example.com")
    assert_includes requester, "reply on the ticket page and the ticket opens again"
    assert_includes requester, "Replies to this email are not read"
  end
end
