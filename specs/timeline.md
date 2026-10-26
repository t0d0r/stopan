# Ticket timeline and audit history

The ticket page shows the description first and then every event in time
order, oldest first. Events are the audit history: they are only ever
inserted.

## Comments

`comments`: `ticket_id`, `author_id`, `body` (required, at most 20,000
characters, plain text), `internal` (boolean, default false), `created_at`,
up to 5 attached files.

- A **public reply** (`internal = false`) is visible to the requester and
  staff.
- An **internal note** (`internal = true`) is visible to staff only. Only
  staff can write one; a requester's `internal` parameter is ignored.
- Comments cannot be edited or deleted (`readonly?` once saved).
- Creating a comment touches the ticket's `updated_at`.

## Events

`ticket_events`: `ticket_id`, `actor_id` (null for the system), `action`,
`from_value`, `to_value`, `comment_id` (for comment events), `internal`
(boolean), `created_at`. No `updated_at`: rows are immutable
(`readonly?` once saved).

| action | written when | values | internal |
|--------|--------------|--------|----------|
| `created` | ticket created | - | no |
| `replied` | public reply added | comment_id | no |
| `noted` | internal note added | comment_id | yes |
| `status_changed` | status changes (manual or automatic) | old / new status | no |
| `priority_changed` | priority changes | old / new priority | yes |
| `assignee_changed` | assignee changes | old / new user id (blank = unassigned) | yes |
| `shared` | share link created or replaced (sharing.md) | to: `password` for a password link, else blank | yes |
| `unshared` | sharing stopped | - | yes |

Assignee values are stored as user ids and shown with the user's current
display name; users that appear in history cannot be deleted (only
deactivated), so the name can always be shown.

`TicketEvent.visible_to(user)` returns all events for staff and only
`internal = false` events for requesters. The ticket page renders only that
scope, so internal text never reaches a requester's HTML.

## Rendering

- Public replies: a sticky in the paper colour of the author's side (staff:
  blue, requester: yellow) with author, role label and time.
- Internal notes: pink paper with an "Internal note" label and padlock icon,
  so they cannot be mistaken for a public reply.
- Property events: one quiet line with an icon, e.g. "Maria changed status
  from Open to Pending - 5 minutes ago".
- Every entry has an anchor (`#event-<id>`) and a `<time datetime>` element.
- Attachments of a comment are listed under its body as download links with
  size.

## Composer

At the end of the timeline, for users who may reply:

- Requester: text area, files, "Send reply". On a closed ticket the composer
  is replaced by "This ticket is closed. Open a new ticket if you need more
  help."
- Staff: a "Public reply" / "Internal note" switch (radio buttons; the form
  turns pink for a note and the button label changes), text area, files,
  "Submit as" status select (keep current, or an allowed transition) and
  the submit button. On a closed ticket only internal notes are offered.

## Live updates of the ticket page

Operator, 2026-10-26: "the ticket page should refresh live too". An open
ticket page (`/tickets/:number`) reloads itself within about a second when
the ticket changes elsewhere, keeping its scroll position.

- **Two streams per ticket**, so a page is only told about what it may
  show: `[ticket, :page, :staff]` gets every event, `[ticket, :page,
  :public]` only non-internal ones. Staff pages subscribe to the staff
  stream, requester pages to the public one; an internal note therefore
  sends nothing to a requester's page, not even the signal.
- **Signal only.** The server broadcasts `<turbo-stream action="refresh">`
  (Turbo 8 page refresh, debounced by turbo-rails) after a ticket event is
  committed; the page fetches itself again over HTTP with the usual
  visibility checks. Changes made through Turbo requests (properties form,
  assignment) carry their request id, and Turbo skips refreshes caused by
  its own recent requests.
- **Who may subscribe:** `TicketsChannel` accepts a stream only for a
  signed-in user who can see the ticket now (`Ticket.visible_to`), and the
  staff stream only for staff. A user who lost access gets no further
  signals, even with an old signed stream name.
- **Work in progress is never thrown away.** A refresh waits while the
  page is busy and runs once it is idle (checked every second): a text
  area or field has typed text, a select differs from its saved value, a
  file is chosen, a field has focus, or a dialog or menu (`<details>`) is
  open. While it waits, a notice above the timeline says the ticket has
  changed elsewhere and will update when the user is done (there is no
  "update now" button: it would throw away what the user is writing).
- Without a WebSocket the page works as before, without live updates.

## Acceptance

Live updates: `test/channels/tickets_channel_test.rb` (who may subscribe)
and `test/integration/ticket_live_updates_test.rb` (the page subscribes to
the right stream; public and internal events reach the right streams).

`test/models/comment_test.rb`, `test/models/ticket_event_test.rb`,
`test/controllers/comments_controller_test.rb` and the flow test cover:
events for every change, immutability, the requester filter, and that a
requester's page contains no internal note text.

## Security Note

The internal flag is decided on the server from the author's role, never
trusted from the form for requesters. Keep any future export or email of a
timeline on the same `visible_to` scope.
