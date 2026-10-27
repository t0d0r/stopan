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
- Comments cannot be deleted. Their text can be edited (see "Editing"
  below); nothing else about a saved comment changes (`readonly?` except
  inside `Comment#edit!`).
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
- **Message title strip** (operator, 2026-10-27: author, role, time and
  "edited by" belong in the header of the original request). The request,
  replies and notes carry all their details in the sticky's title strip,
  left to right: the kind icon and caption ("Original request", "Reply
  from the service desk", "Internal note", ...), the author's name in
  bold, the role label, the time, the "Visible to staff only" tag for
  notes and the "edited by <name> <time>" marker; at the right end the
  boxes: Edit (pencil, for users who may edit), Markdown and Copy. The
  body below holds only the text, earlier versions and files. On narrow
  screens the strip wraps onto a second line instead of cutting text off.
  The same strip is used on shared pages (without the Edit and Markdown
  boxes).
- Attachments of a comment are listed under its body as download links with
  size.

## Editing

Requested by the operator on 2026-10-27: "an option to edit replies and
original requests".

| what | requester | agent / admin |
|------|-----------|---------------|
| the request (subject and description) | own ticket (`TicketPolicy#own?`), not closed | any ticket |
| a public reply | own reply on own ticket, not closed | any reply |
| an internal note | never visible | any note |

Staff may edit anyone's text, so they can correct or redact (for example a
password a customer pasted); every edit is kept and shown (below), so this
cannot hide who wrote what.

- **Only the text.** Subject and description of the request; the body of
  a reply or note. Files, author, visibility (`internal`), and times stay
  as they are. Same validation as on create (subject 1-200 characters,
  text 1-20,000). Saving unchanged text changes nothing.
- **Routes:** `GET/PATCH /tickets/:number/description(/edit)`
  (`TicketDescriptionsController`) and `GET/PATCH
  /tickets/:number/comments/:id(/edit)` (`CommentsController#edit`,
  `#update`). The ticket is loaded through `Ticket.visible_to`, the
  comment through `Comment.visible_to` on that ticket (404 otherwise); the
  policy (`TicketPolicy#edit_description?`, `#edit_comment?(comment)`)
  decides the rest (403).
- **UI:** an "Edit" link with a pencil icon in the message's meta line for
  users who may edit it. With JavaScript the text turns into a form in
  place (a Turbo frame around the text); without it the edit page shows
  the same form. "Save" goes back to the ticket at the message with a
  notice ("Reply updated." / "Internal note updated." / "Request
  updated."); "Cancel" restores the text. Errors re-render the form
  (422).
- **Double-click to edit** (plan item 3, from g0no's locked notes): a
  double-click on the text of a message the user may edit opens the same
  in-place form, as the pencil box does; a double-click on a link, check
  box or button does nothing special. The caret is put near the clicked
  place: the text before the click, as shown, is matched against the
  plain text ignoring white space and Markdown punctuation (`* _ ~ ` | #
  > [ ] ( ) ! \ -`; its last 30 visible characters, then
  shorter pieces, so Markdown syntax in between does not stop it; the
  occurrence closest to the click's position wins); without a match the
  caret goes to the end. Focusing never scrolls the page. The pencil
  box's tooltip says "Edit (or double-click the text)".
- **Escape** in an edit form cancels it (like "Cancel") while nothing was
  changed; with changes it does nothing, so typed text is never thrown
  away by a key.
- **Marked as edited.** An edited message shows "edited by <name> <time>"
  in its meta line, for everyone who can see the message (also on a
  shared page), so a requester knows when staff changed their text.
  Columns `edited_at` and `edited_by_id` on `tickets` and `comments`.
- **Earlier versions are kept** in `revisions` (one row per edit: the
  record, the text before the edit, who made the edit and when; the
  subject too for the request). Staff see them under an edited message in
  a collapsed "Earlier versions (n)" list, newest first, each headed
  "Before the edit by <name> <time>". Requesters and shared pages never
  see earlier versions, also of their own text.
- **Not activity.** An edit writes no timeline event, sends no email or
  notification and does not change the ticket's `updated_at` (queue
  order): it corrects what was said, it does not say something new.
- **Live:** an edit refreshes open pages like an event would: the staff
  ticket page always; for the request or a public reply also the
  requester's page, the requester's list, the queue and the shared page;
  for an internal note only staff pages.

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

Editing: `test/models/revision_test.rb` (edits keep the previous text,
unchanged text is a no-op, validation, no event, `updated_at` untouched)
and `test/controllers/edits_controller_test.rb` (who may edit what per
role, closed tickets, internal notes hidden from requesters, earlier
versions only for staff, the edited marker on the shared page, live
signals).

## Security Note

The internal flag is decided on the server from the author's role, never
trusted from the form for requesters. Edits never change it. Earlier
versions keep the old text, so redacting a secret by editing hides it
from requesters and shared pages but not from staff or the database;
removing it everywhere needs an administrator at the database. Keep any future export or email of a
timeline on the same `visible_to` scope.
