# Board (kanban)

Requested by the operator on 2026-10-27: "generate kanban similar to
fizzy.do" (37signals' Fizzy). Fizzy's board, as seen on its site and help
guide: columns side by side, the ones in use expanded with their cards,
the others collapsed into tall coloured pills with a count and a vertical
label; white cards with a coloured strip (number and board), a large bold
title, then "13 days ago", "updated yesterday" and the people with small
avatars; cards move by drag and drop or from a list of columns; a "golden
ticket" floats a card to the top. Stopan takes that look for its ticket
statuses.

## Page

- `GET /tickets/board`, staff only (requesters get 403; their lists stay
  My tickets). The queue's header has a "List | Board" switch; the board
  has the same switch, so staff move between the two views.
- One column per status, in order: New, In progress (open), Pending,
  Resolved, Closed, each in its status colour (ui.md). New, In progress
  and Pending start expanded; Resolved and Closed start collapsed.
- A **collapsed column** is a tall rounded pill in its colour: the count
  at the top, the status name written vertically below. Clicking it (or
  Enter / Space) expands the column; an expanded column's header has a
  collapse box. Which columns are expanded is remembered per browser
  (`localStorage`, a convenience; without it the defaults apply).
- An **expanded column** has a header with the status name and the count,
  and its cards below, at least 290px wide. The board scrolls sideways
  inside itself when the columns do not fit; the page never does.
- Resolved and Closed show the 50 most recently active cards, with "and
  N more in the list" linking to the queue's Solved view; the other
  columns show every card. Counts are the full numbers.
- Filters: the board takes the queue's assignee and organization filters
  (`assignee`, `organization` parameters, the same selects without an
  Apply button); a set filter is highlighted.

## Card

- A white card with a thin border in the column colour.
- Strip at the top in the column colour: `#1003 | GLOBEX LOGISTICS` (the
  number and the organization, upper case, small), and a priority mark
  for high ("High") and urgent ("Urgent", see golden cards).
- The subject, large and bold (at most three lines, then cut with an
  ellipsis), linking to the ticket page.
- Meta, small upper-case text: "3 days ago" (created) and a refresh icon
  with the last activity ("yesterday"); below, the requester's initials
  badge and name, an arrow, and the assignee's badge and name, or
  "Unassigned".
- **Golden cards:** urgent tickets are drawn in gold (yellow paper, a gold
  border) and always sit at the top of their column, like Fizzy's golden
  tickets. Order within a column: urgent first, then high, then most
  recent activity.
- A shared ticket shows the link icon after the subject.

## Moving cards

- **Drag and drop** a card onto another column (expanded or collapsed):
  `PATCH /tickets/:number/move` with `status`, through Turbo's `fetch`
  (so this tab skips its own live refresh). Only allowed transitions
  (tickets.md) are drop targets: while dragging, the others are dimmed and
  refuse the drop. On success the card moves into the column at its
  place and the counts change; on an error (a refused transition, a
  ticket changed meanwhile) the card goes back and a pink notice says
  why. The move is an ordinary status change: a timeline event,
  notifications and live refresh for everyone else.
- **Without dragging** (keyboard, touch, no JavaScript): every card has a
  small "Move" menu (a `<details>` with one button per allowed status);
  it posts to the same route and comes back to the board with a notice.
- `move` answers 204 for `fetch` requests and redirects back to the board
  (the `Referer` when it is the board, else the board) for forms; errors
  are 422 with the message as text for `fetch`, an alert for forms. Staff
  only (403).

## Live

The board listens to the staff queue stream (queues.md "Live updates"),
so it reloads itself when tickets change elsewhere, keeping its scroll
position; a reload waits while a card is being dragged or a Move menu is
open (the busy check, timeline.md).

## Not in this phase

Custom columns, reordering cards by hand, a "Not now" lane, automatic
postponing after inactivity (Fizzy's auto close; roadmap.md lists
auto-close of resolved tickets), card background images.

## Acceptance

`test/controllers/boards_controller_test.rb` (staff only, columns and
counts, card content, golden order, the 50-card limit for solved
columns, filters) and `test/controllers/ticket_moves_test.rb`
(allowed and refused transitions, 204 and 422 for fetch, redirect for
forms, events written, staff only).

## Security Note

The board shows the same data as the queue and only to staff; moving a
card is the same status change as on the ticket page, with the same
transition rules and events, so it opens no new path to change tickets.
