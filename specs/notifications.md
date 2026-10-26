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

## Notification panel (in the app)

Requested by the operator on 2026-10-26: "let there be a notification
panel". Every notification decided above is also stored for the app, so
people see it even when email is off (no `SMTP_ADDRESS`) or missed.

- **Same rules as email.** `TicketNotifier` creates one `notifications` row
  per recipient and batch, with the same recipient and kind as the email
  (actor rule, visibility, deactivated users, one per person per action).
  New-ticket notifications go to the same opted-in staff.
- **Menu bar bell** (signed-in users, left of the theme switch): a bell
  button with the number of unread notifications (hidden at 0, "9+" above
  9); its accessible name says the count ("Notifications, 3 unread"). It
  opens a panel (a small yellow sticky, `<details>`) with the 8 newest
  notifications, newest first: the actor's initials badge, a sentence
  ("Maria Ivanova replied", "... changed the status to Pending", "...
  assigned the ticket to you", "... opened a new ticket", "... added an
  internal note"), the ticket's number and subject, and the time. Unread
  ones are bold with a dot. Footer: "Mark all as read" and "All
  notifications". Empty: "No notifications yet."
- **Opening a notification** (`GET /notifications/:id`) marks it read and
  redirects to the ticket at the event (`#event-<id>`). Only the user's own
  notifications are found (404 otherwise).
- **Opening a ticket page** marks the user's notifications of that ticket
  read, so the badge does not count what the user has already seen.
- **Mark all as read:** `PATCH /notifications/read_all`, back to the page
  the user came from (same host) or to the list.
- **All notifications:** `GET /notifications`, 50 per page, same rows.
- **No text from the ticket body.** A notification shows only the kind,
  the actor, the new status, the ticket number and subject - never reply
  or note text - so the panel cannot leak more than the ticket list does.
- **Checked again when shown.** Lists only show notifications whose ticket
  is in `Ticket.visible_to(user)` now; for non-staff, internal kinds
  (`noted`) are never shown, even if the user's role changed.
- **Retention:** each user keeps the 200 newest; older rows are deleted
  when a new one is created.
- The panel closes on a click outside or Escape.

### Live updates of the panel

Requested by the operator on 2026-10-26. The bell's count and the panel
update within about a second, without reloading the page, when a
notification arrives or the user reads notifications in another tab.

- **Signal only, content over HTTP** (as g0no's live updates): signed-in
  pages subscribe with `turbo_stream_from current_user, :notifications`
  (a signed stream name per user). The server broadcasts only
  `<turbo-stream action="notifications_refresh">`, never notification
  content. The page then fetches `GET /notifications/panel` (the bell and
  panel HTML, no layout, `Cache-Control: no-store`) with its own session,
  so sign-in and `Notification.visible_to` are checked as on any request.
- **Broadcasts:** after a notification is created (after commit), and
  after notifications are marked read (opening one, opening its ticket,
  "Mark all as read"), to that user's stream. `broadcast_action_later_to`
  on the in-process job adapter.
- **Client** (`application.js`): a custom Turbo Stream action
  `notifications_refresh`; refreshes are coalesced (300 ms), and while the
  panel is open the refresh waits until it is closed, so a list the user
  is reading does not change under the pointer. The new `<details>`
  replaces the old one.
- **Connections need a signed-in, active user**
  (`ApplicationCable::Connection` reads the Devise session from Warden and
  rejects others). Action Cable accepts only the app's own origin
  (`allow_same_origin_as_host`, the default).
- **Adapter:** `async` (`config/cable.yml`), one Puma process; several
  processes would need solid_cable or Redis.
- **Without a WebSocket** (blocked proxy, old browser) the panel updates on
  page load, as before. Production needs `upgrade=websocket` on the Apache
  `ProxyPass` line for `/cable` (deploy.md); until then it works this way.

Data: `notifications` - `user_id` (FK, deleted with the user), `ticket_id`
(FK), `actor_id` (FK users, nullable), `kind` (the email kinds),
`event_id` (the event to jump to, nullable), `status` (new status for
`status_changed` and when a reply changed it, nullable), `read_at`,
`created_at`. Indexes `[user_id, created_at]` and `[user_id, read_at]`.

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
