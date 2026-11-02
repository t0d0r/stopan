# Followers and Cc

2026-11-02: "do we have an option to add watchers / collaborators?" and
then "do it" for the proposal. A ticket has one requester and one
assignee. Two more groups of people can now be on a ticket. They have
different rights, because one group is staff and the other is the
customer.

| | staff followers | Cc (customer side) |
|-|-----------------|--------------------|
| who | active staff who are members of the ticket's organization | requesters who are members of the ticket's organization, other than the ticket's requester |
| what they see | what they already see as staff: everything, internal notes included | the public part only, like the requester |
| emails and in-app notifications | like the assignee: public replies, internal notes, status changes | like the requester: public replies and status changes |
| may reply | yes, as staff | yes, public replies, in Stopan and by email |
| added by | themselves ("Follow"), any staff who may update the ticket, or automatically on writing a reply or note | staff who may update the ticket, by email address or from the mail's To/Cc |

## Data

`ticket_followers`:
- `ticket_id` and `user_id`, both required, unique together;
- `added_by_id` (nullable, the user who added them);
- timestamps.

Rows are removed with their ticket (flush), and with their user when an
account without history is deleted. The kind comes from the user's role:
staff follow, requesters are Cc. The model validates:
- the user is active;
- the user is a member of the ticket's organization;
- a requester is not the ticket's own requester.

## Visibility

`Ticket.visible_to` for a requester covers two sets, both only in
organizations the requester still belongs to:
- the tickets they requested;
- the tickets they are Cc on.

Everything that goes through that scope follows:
- "My tickets", search and the ticket page;
- files and notifications;
- live streams and magic link return pages;
- email replies.

`TicketEvent.visible_to` and `Comment.visible_to` still give
requesters only the public part, so a Cc never sees an internal note or
event. Removing the membership removes the access at once, and so does
removing the person from Cc.

"My tickets" lists Cc tickets with a "Cc" tag next to the subject.

What a Cc may do on a ticket (`TicketPolicy`):
- reply publicly;
- edit their own public replies.

What stays with the requester:
- marking the ticket done;
- editing the request;
- sharing it.

## The panel "People"

A green side panel under "Requester" (closed on phones like the others,
ui.md "Ticket page on phones").

**Staff see:**
- "Following" with each staff follower, and a "Remove" button for each;
- "Follow" or "Stop following" for themselves;
- an "Add a colleague" select of the organization's staff who are not
  following yet (`Ticket#assignable_staff`), with an "Add" button;
- "Cc" with each person in copy (name and email) and a "Remove" button
  for each;
- an "Add to Cc" email field with an "Add" button;
- **suggestions:** the addresses from the mail's To and Cc
  (organization-mail.md "Mail details"), each with an "Add to Cc"
  button. The list leaves out:
  - the requester;
  - people already in Cc;
  - staff;
  - the organization's own `mail_from` and `mailbox_address`.
  An address is never added on its own. **Reason:** a wrongly copied
  address would receive every reply.

**The requester and the people in Cc see:**
- "Cc" with names only, when there is anyone;
- no staff followers.

**Without anyone to list**, a customer does not see the panel.

## Adding to Cc by email

- The address is normalized (trimmed, lower case), and must be a valid
  email address.
- **An existing requester** is used, and is added to the ticket's
  organization when not yet a member. These are the same rules as an
  email to the organization's mailbox (organization-mail.md "Processing
  a message").
- **An unknown address** gets a new requester account: the name is the
  part before `@`, with a random password and `password_chosen` false.
  They also get the organization membership. They sign in with
  "Email me a sign-in link" (public-form.md "Magic sign-in links"), or
  simply answer by email.
- **Refused, with a message:**
  - staff addresses ("is staff: add them as a follower");
  - deactivated users;
  - the ticket's requester;
  - people already in Cc.
- Adding sends no email of its own. The person gets the next public
  reply or status change.

## Following automatically

Staff who write a public reply or an internal note on a ticket become
followers, unless they already are or may not be (no membership). This
adds no event. They can stop following at any time.

## Notifications and emails

- `TicketNotifier` candidates are:
  - the requester;
  - the assignee;
  - the followers (staff and Cc);
  - subscribers, for a new ticket only.
  The existing rules apply unchanged:
  - the actor is never told;
  - deactivated users are skipped;
  - the recipient must see the ticket;
  - the kind comes from the events the recipient may see, so a Cc never
    gets a note.
- The "Email the requester" switch (notifications.md "Emails to the
  requester") now covers **the customer side**: the requester and every
  Cc.
  - Its label becomes "Email the requester and Cc".
  - Its warning lists every address that will get mail.
  - While it is off, none of them gets an email; they still get the
    in-app notification.
- Every email to the customer side is recorded in the timeline with its
  address (`mail_sent`, `mail_skipped`, `mail_failed`). The reason or
  error is stored in `ticket_events.detail`. Events recorded before that
  column showed "the requester" in place of the address.
- The email names why the person gets it:
  - followers: "You get this email because you follow this ticket.";
  - Cc: "You get this email because you are in copy (Cc) on this ticket."
  Cc get the requester's footer: answer by email when the
  organization's mailbox is the Reply-To.
- **People in Cc get the shared page, on every ticket** (2026-11-02: a
  Cc without an account got "Open ticket #1012", a page that needs a
  sign-in, and "they must get the shared link"). The requester's emails
  keep the rule of sharing.md "Link in the requester's emails" (tickets
  from email only).
  - The first email to a Cc makes the link when none exists
    (`Ticket#share_for_customer!`). As for the requester, its password
    is the requester's address.
  - The shared page also takes **the Cc's own address** as the password
    (`Ticket#customer_share_password?`), so the email can say "the
    password is your email address". Only while the person is still in
    Cc and a member of the organization, and only on that automatic link:
    a password set by staff is never bypassed. With such a password the
    email keeps the ticket page link.
  - An open link (no password) is given as it is.

## Email replies

A mail from a person in Cc that refers to the ticket becomes a public
reply by them, like the requester's (organization-mail.md "Processing a
message", step 3). This holds while they are in Cc and members of the
organization.

## Events

All follower events are internal, so customers and shared pages never see
them.

| action | values | shown as |
|--------|--------|----------|
| `follower_added` | from `staff` or `cc`, to the user id | "Maria follows the ticket" (themselves), "Maria added Petar as a follower", "Maria added Ivan Petrov to Cc" |
| `follower_removed` | the same | "Maria stopped following", "Maria removed Petar as a follower", "Maria removed Ivan Petrov from Cc" |

Like the mail events, these events notify nobody.

## Routes

- `POST /tickets/:number/followers`, with one of:
  - `user_id` (themselves or a colleague);
  - `email` (Cc).
- `DELETE /tickets/:number/followers/:id`.
- Both are for staff who may update the ticket. Anyone else gets a 403;
  a hidden ticket is a 404. Both answer with a redirect to the panel and
  a flash.

## Not in this phase

- Requesters adding colleagues to Cc themselves, and a Cc leaving.
- People outside the organization (the share link remains for them).
- Followers in the API.
- Digests.
- Taking Cc from the headers of later email replies.

## Acceptance

- `test/models/ticket_follower_test.rb`:
  - who may follow and be Cc;
  - `add_cc!` with an existing, new, staff or deactivated address;
  - auto-follow;
  - flush removes the rows.
- `test/controllers/ticket_followers_controller_test.rb`:
  - the panel for staff and for customers;
  - adding and removing;
  - 403 for requesters, 404 outside the organization;
  - the suggestions.
- `test/integration/cc_access_test.rb`:
  - a Cc sees the ticket's public part and no internal note;
  - a Cc sees the ticket in My tickets and can reply;
  - a Cc cannot mark it done, edit the request or share;
  - a Cc loses access when removed;
  - a Cc's email reply becomes a public reply.
- Notifier tests:
  - followers and Cc are emailed per their scope;
  - the switch covers Cc;
  - mail events carry the address.

## Security Note

A Cc is the second way, after the requester, in which a customer reads a
ticket. It goes entirely through `Ticket.visible_to` and the public
scopes, and is tied to the membership. Adding by email can create an
account and a membership, exactly as an email to the mailbox would, so
only staff who may update the ticket can do it. Mail headers suggest
addresses but never add them.
