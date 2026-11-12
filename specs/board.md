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
- One column per status, in order: Not now, New, In progress (open),
  Pending, Done, each in its status colour (ui.md). New, In progress and
  Pending start expanded; Not now and Done start collapsed.
- A **collapsed column** is a tall rounded pill in its colour: the count
  at the top, the status name written vertically below. Clicking it (or
  Enter / Space) expands the column. Clicking anywhere on an expanded
  column's header collapses it again (operator, 2026-10-27: "close and
  open with a click, like open"); the header's collapse box does the
  same from the keyboard. Which columns are expanded is remembered per browser
  (`localStorage`, a convenience; without it the defaults apply).
- An **expanded column** has a header with the status name and the count,
  and its cards below, at least 290px wide.
- **Scrolling** (operator, 2026-10-27: "make better scroll"): the board
  spans the whole window width (not the desk's 1120px) and fits the
  window's height from its top to the bottom edge (recomputed on resize),
  so its sideways scrollbar is always in view; each expanded column
  scrolls its own cards up and down under its fixed header. Scrollbars
  are thin and tinted; sideways scrolling snaps gently to column starts.
  When the columns need less than the window's width (many collapsed),
  they sit centred (operator, 2026-10-27: "let them be centred"); when
  they need more, the board scrolls from the first column.
  While a card is dragged within 80px of the board's left or right edge,
  the board scrolls that way. The page itself never scrolls sideways.
- Columns without cards start collapsed, unless the user expanded them
  (the remembered choice wins).
- Done shows the 50 most recently active cards, with "and N more in the
  list" linking to the queue's Done view; the other
  columns show every card. Counts are the full numbers.
- **Filters, the same as the list** (operator, 2026-10-27: "lets board
  view to have same filters as list"): Status, Priority, Assignee,
  Organization and Sort, with the same parameters (`status`, `priority`,
  `assignee`, `organization`, `sort`), the same selects without an Apply
  button (one shared partial, `tickets/_filters`), and the menu bar
  search (`q`) kept while filtering. A set filter is highlighted; "Clear
  filters" goes back to the plain board. The board has no views, so
  every ticket the user may see is on it. Advanced search is only on the
  search page (queues.md "Search page"). The filters sit on one row with
  the List | Board switch at its right end, a rule under
  the whole row (2026-10-28: "on one row"); on narrow screens they wrap.
  - Status shows only that status's column and its stage columns.
  - Sort orders the cards within each column: golden (urgent) cards stay
    on top, then high, then the chosen order: last activity (default),
    newest created first, or by priority (normal before low).
  - "and N more in the list" carries the filters to the queue's Done
    view.

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
  recent activity (or the order chosen with the Sort filter).
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
- **Several cards at once** (2026-11-12: "let me move several tickets
  on the board"):
  - Every card has a small check box at its top left, beside the
    number ("Select #1042"). Ticked cards get a blue ring.
    Shift+click on another box ticks every card in between, in the
    order of the board (ui.md "Check box lists"); Escape clears the
    selection.
  - **Dragging a ticked card drags all ticked cards.** The pointer
    carries a tag with their number ("3 tickets"). A column takes the
    drop when at least one of them may move there. On the drop each
    card that may move is moved, one request each, as a single card
    is; the others stay where they are, and a notice says how many
    were not moved ("2 of 5 tickets could not be moved there."). The
    selection is cleared after the drop. Dragging a card that is not
    ticked moves only that card, as before.
  - **Without dragging:** while cards are ticked, a bar above the
    board shows how many ("3 selected"), a "Move to" list of the
    statuses, "Move" and "Clear". "Move" sends the ticked numbers to
    the queue's bulk action (`PATCH /tickets/bulk`, queues.md "Bulk
    actions"), which comes back to the board with its notice and the
    skipped tickets and their reasons. Stages are chosen by dragging
    or by a card's own Move menu.
  - The selection lives in the page: a live refresh keeps it (the
    board waits while cards are ticked, as it does for an open Move
    menu), a reload forgets it.
- **Without dragging** (keyboard, touch, no JavaScript): every card has a
  small "Move" menu (a `<details>` with one button per allowed status);
  it posts to the same route and comes back to the board with a notice.
- The bulk action's `return_to` may be the board (`/tickets/board`
  with its filters) as well as a list or the search page.
- `move` answers 204 for `fetch` requests and redirects back to the board
  (the `Referer` when it is the board, else the board) for forms; errors
  are 422 with the message as text for `fetch`, an alert for forms. Staff
  only (403).

## Live

The board listens to the staff queue stream (queues.md "Live updates"),
so it reloads itself when tickets change elsewhere, keeping its scroll
position; a reload waits while a card is being dragged or a Move menu is
open (the busy check, timeline.md).

## Not now, automatic postponing and stages

Added on 2026-10-27 at the operator's request ("add" the three proposals:
a "Not now" status, automatic postponing with a stamp, sub-columns).

### Not now

- The status `postponed` (tickets.md), purple, shown as "Not now"
  ("Отложена"). On the board it is the leftmost column, collapsed by
  default, like Fizzy's NOT NOW.
- Requesters see it as their ticket's status and in their "Open" tab;
  they get the in-app notification of the change but **no email** when
  their ticket is postponed (manually or automatically); their reply
  reopens it.

### Automatic postponing

- Administrators set the number of days in `/admin/settings` ("Postpone
  tickets after N days without activity"; default 30; 0 turns it off).
  The setting is one row of `app_settings` (`auto_postpone_days`).
- Once an hour the web process (started under `rails server`, like the
  mailbox poller; `bin/rails stopan:postpone_inactive` by hand) moves
  every `new`, `open` or `pending` ticket whose last activity is older
  than N days to `postponed`, one transaction per ticket, as a status
  event without an actor (the timeline says "Stopan moved it to Not now",
  public like every status change). Notifications follow the rule above
  (in the app, no email to the requester).
- **Stamp:** a card that will be postponed within 7 days shows a round
  stamp at its top right, like Fizzy's "closes in": "Not now in 3 days"
  (the number large, the words around it small); "today" when it is due
  in less than a day. Staff also see "Moves to Not now in 3 days" under
  the status on the ticket page.

### Automatic done (2026-11-12)

roadmap.md had "auto-close resolved tickets after N days". Since
`resolved` and `closed` became `done` (tickets.md), the ticket that
waits to be closed is the `pending` one: staff answered and the
requester never came back.

- Administrators set the number of days in `/admin/settings`, in the
  same panel as postponing ("Mark pending tickets done after this many
  days without activity"). The default is 0, which turns it off, so
  nothing closes until an administrator asks for it. The setting is
  `app_settings.auto_done_days` (0 to 3650).
- Once an hour, before the postponing, every `pending` ticket whose last
  activity (`updated_at`) is older than N days becomes `done`: one
  transaction per ticket, a status event without an actor, public like
  every status change. `bin/rails stopan:close_pending` does it by hand.
- **Notifications** are those of any change to Done: the requester and
  the people in Cc get the email, which says that a reply opens the
  ticket again (notifications.md). **Reason:** unlike "Not now", the
  ticket leaves the requester's open list, so they must be told.
- A reply by the requester opens the ticket again, as always.
- **With postponing on too**, a pending ticket meets the shorter of the
  two periods first. With equal periods it is marked done.
- Staff see "Marked done in 3 days without activity." under the status
  on the ticket page during the last 7 days ("today" on the last one),
  in place of the "Not now" line when done comes first. Such a card
  shows no "Not now" stamp on the board.
- The API has the setting as `auto_done_days` (api.md).

### Stages (sub-columns)

- Administrators define stages for a status in `/admin/settings`, for
  example "Investigating" and "QA to confirm" for In progress: a name (at
  most 40 characters), a colour from the paper set, and an order; rename,
  recolour, move up or down, delete (tickets in a deleted stage go back to
  the plain status). Table `stages` (`status`, `name`, `color`,
  `position`); `tickets.stage_id` (nullable).
- On the board every stage is its own column right after its status's
  column, with its colour and the label "In progress / Investigating";
  it collapses and expands like the others. Cards in a stage sit only in
  the stage column.
- Dragging a card to a stage column sets the status (when different,
  under the usual transition rules) and the stage; to the plain status
  column it clears the stage; the Move menu lists stages too. A status
  change anywhere else clears a stage that belongs to another status.
- Stages are for staff only: a stage change is an internal event
  ("Maria moved it to Investigating"), requesters never see stages, and
  staff see the stage on the ticket page (a Stage select in Properties)
  and as "In progress · Investigating" in the queue.

## Not in this phase

Reordering cards by hand (Fizzy has none either: golden tickets are the
only way to the top), card background images, per-board settings.

## Acceptance

`test/controllers/boards_controller_test.rb` (staff only, columns and
counts, card content, golden order, the 50-card limit for the done
columns, filters, the Not now column, stage columns, stamps),
`test/models/auto_done_test.rb` (only pending tickets, the event, the
email to the requester, off at 0, the shorter period wins),
`test/models/auto_postpone_test.rb` (who is postponed, events, no email
to requesters, the setting, off at 0),
`test/controllers/admin/settings_controller_test.rb` (the setting and
stages, admins only) and `test/controllers/ticket_moves_test.rb`
(allowed and refused transitions, 204 and 422 for fetch, redirect for
forms, events written, staff only).

## Security Note

The board shows the same data as the queue and only to staff; moving a
card is the same status change as on the ticket page, with the same
transition rules and events, so it opens no new path to change tickets.
