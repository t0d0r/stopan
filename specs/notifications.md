# Email notifications

Phase 2, first item of specs/roadmap.md. Stopan emails people about ticket
changes they did not make themselves. Email is one-way in this phase:
replies to a notification are not read (email ingestion is a later item).

## Principles

- **Nobody is emailed about their own action.** The actor of a change
  never gets a notification for it.
- **One email per person per action.** One user action (create a ticket,
  reply and set a status, change several properties) is one database
  transaction and writes one or more ticket events. Those events form a
  *batch*; each recipient gets at most one email for it.
- **The same visibility rules as the web pages.** What a recipient may be
  told is decided by `Ticket.visible_to(recipient)` and
  `TicketEvent.visible_to(recipient)` (specs/roles.md); notifications never
  filter on their own. A requester is therefore never told about internal
  notes, priority or assignee changes, and nothing is sent to a requester
  who has lost access to the ticket's organization.
- **Checked again at sending time.** The mailer reloads the recipient, the
  ticket and the events and repeats both checks, so a change between
  queueing and sending (deactivation, removed membership) is respected.
- **Deactivated users get no email.**

## Recipients

For a batch on ticket T made by actor A, the candidates are:

| candidate | when |
|-----------|------|
| T's requester | always |
| T's assignee (after the change) | always |
| staff with "email me about new tickets" on | only for a batch with a `created` event |

Each candidate is dropped when they are A, deactivated, cannot see T, or
can see none of the batch's events. A person who is both requester and
assignee, or assignee and subscriber, gets one email.

## Which email

The first matching row decides the email, looking only at the events the
recipient may see:

| visible events contain | email | to whom it applies |
|------------------------|-------|--------------------|
| `created` | **new ticket** - subject, requester, organization, priority, description; "assigned to you" when the recipient is the assignee; for the requester "<A> opened this ticket for you" | requester (when staff opened it for them), assignee, subscribers |
| `replied` | **new reply** - author, reply text, names of attached files, and the new status when the same action changed it | requester, assignee |
| `noted` | **internal note** - author, note text, file names, new status if changed | assignee (staff only by visibility) |
| `assignee_changed` to the recipient | **assigned to you** - requester, organization, status, priority, description | the new assignee |
| `status_changed`, except `new` -> `open` | **status changed** - from, to; for `resolved` the requester is told that replying reopens the ticket; for `pending` that the desk waits for their answer | requester, assignee |

Nothing else sends email: priority changes alone, unassignment and the
`new` -> `open` triage step do not.

Examples:

- A requester opens a ticket -> subscribed staff get "new ticket"; the
  requester gets nothing (they just saw the page).
- An agent replies and sets "pending" -> the requester gets one "new reply"
  email that also says the status is now "Pending"; the assignee, if it is
  another agent, gets the same.
- An agent adds an internal note -> only the assignee (if another person)
  is told; the requester's visible events are empty, so nothing is sent.
- The requester marks a ticket resolved -> the assignee gets "status
  changed".
- An administrator demotes an agent, which unassigns their tickets -> no
  email (the events are internal to staff, and nobody is the new
  assignee).

## Content

- **Language:** the recipient's `users.locale`, else English. The app
  stores the language of the browser each signed-in user last used (only
  when the browser sent a supported `Accept-Language`).
- **Subject:** `[Stopan #1001] <kind>: <ticket subject>`, kinds translated.
- **Body:** HTML and plain-text parts. User text (subject, description,
  reply and note bodies, file and user names) is escaped in HTML and
  shown as-is in the text part. Attachments are listed by name only, never
  attached; downloading still needs a signed-in, authorized user.
- **Link** to the ticket page (`APP_HOST`, https in production).
- **Footer:** why the recipient gets the email (requester / assignee /
  subscribed to new tickets) and that replies to the email are not read;
  subscribers get a link to their account page to turn it off.
- **Threading:** every email of a ticket carries `References:
  <ticket-1001@APP_HOST>` so mail clients group them.
- **From:** `MAILER_SENDER`, the same as Devise.

## Settings

- Account page (`/users/edit`), staff only: a separate "Notifications" form
  with the checkbox "Email me about every new ticket" (`PATCH
  /users/notifications`, no current password needed, only this field is
  accepted). Default off.
- Requesters and assignees cannot turn their ticket emails off in this
  phase (roadmap: per-user preferences).

## Delivery

- `ActionMailer` `deliver_later` after the transaction commits
  (`ActiveRecord::Base.current_transaction.after_commit`), so a rolled
  back action sends nothing and the request does not wait for SMTP.
- Active Job uses Rails' default in-process `:async` adapter. Emails
  queued in the seconds before a restart are lost, and a failed delivery
  is logged, not retried. A durable queue (Solid Queue) is a later item.
- Devise's password reset email stays synchronous (specs/auth.md).

## SMTP (production)

Read from the environment at boot (`config/environments/production.rb`):

| variable | default | purpose |
|----------|---------|---------|
| `SMTP_ADDRESS` | - | SMTP host; when empty, email is switched off (`perform_deliveries = false`) and a warning is logged at boot |
| `SMTP_PORT` | 587 | port |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | - | credentials; authentication is used only when a username is set |
| `SMTP_AUTHENTICATION` | plain | `plain`, `login` or `cram_md5` |
| `SMTP_TLS` | false | `true` for implicit TLS (port 465); otherwise STARTTLS is used when offered |
| `SMTP_DOMAIN` | - | HELO domain |

Timeouts are 5 s to connect and 10 s to read. Development writes emails
to `tmp/mails/` (`delivery_method :file`); tests use `:test`.

## Data

- `users.locale` string, nullable (`en` / `bg`).
- `users.notify_new_tickets` boolean, not null, default false; only
  meaningful for staff (ignored for requesters).

## Code

- `TicketEvent` after create -> `TicketNotifier.collect(event)`: adds the
  event to the batch kept on its ticket object and, for the first event,
  registers one after-commit callback on the current transaction.
- `TicketNotifier` decides recipients and kinds (rules above) and calls
  `TicketMailer.with(recipient:, ticket:, event_ids:).<kind>.deliver_later`.
- `TicketMailer` repeats the visibility checks and renders one template
  (`ticket_mailer/notification`, HTML and text) for all kinds.
- `Users::NotificationsController#update` saves the opt-in.
- `ApplicationController#remember_locale` stores the browser language.

## Acceptance

`test/models/ticket_notifier_test.rb` performs the queued jobs, so it
covers the notifier and the mailer's own checks together: each example
above, the actor rule, deactivated users, a requester removed from the
organization (no email, also when it happens after queueing), no internal
text in requester emails, one email per person per action, rollback sends
nothing, the recipient's language, escaping of user text in HTML and plain
text in the text part, and the threading header.
`test/controllers/notifications_controller_test.rb` covers the
subscription form (staff only, only that field) and the remembered
language.

## Security Note

Notifications are the easiest place to leak internal notes. The mailer
itself re-applies `TicketEvent.visible_to` at sending time, and a test
asserts that internal note text never appears in a requester's email. SMTP
credentials come only from the environment, never from the repository.
