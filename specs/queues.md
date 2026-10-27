# Ticket lists: agent queue and "My tickets"

Both are `GET /tickets` (`TicketsController#index`), which is also the
start page (`/`). Staff get the queue; requesters get "My tickets". Every
list query starts from `Ticket.visible_to(current_user)`.

## Agent queue (staff)

Layout: a horizontal row of view tabs under the page title, like the
admin section tabs (operator, 2026-10-26), then the list panel with the
filter bar and the table at full width. The row wraps onto more rows when
it does not fit, on phones too, with tighter tabs under 760px (operator,
2026-10-27: no sideways scrolling on mobile; before, it scrolled
sideways under 760px). The search field is in the menu bar
(see "Search" below).

### Views (`view` parameter)

| view | tickets | default |
|------|---------|---------|
| `unsolved` | new, open, pending | yes |
| `mine` | unsolved and assigned to me | |
| `unassigned` | unsolved and without assignee | |
| `pending` | pending | |
| `done` | done ("Done"; was `solved` before 2026-10-27, which now falls back to the default view) | |
| `all` | every ticket | |

Each view shows its count. Every view has a paper colour (ui.md), shown
as a small square and a coloured count; the current view is drawn as a
small sticky in its colour, and the list panel takes the same colour:

| view | colour |
|------|--------|
| `unsolved` | yellow |
| `mine` | purple |
| `unassigned` | pink |
| `pending` | blue (as the pending status) |
| `done` | green (as the done status) |
| `all` | gray |

### Filters (combined with the view, all optional)

| parameter | values |
|-----------|--------|
| `status` | one status |
| `priority` | one priority |
| `assignee` | a staff user id, `me`, or `none` |
| `organization` | an organization id |
| `requester` | a requester's user id (staff; people.md "Queue filter") |
| `q` | search text (from the menu bar search): `#1001` or `1001` also matches the ticket number; otherwise case-insensitive substring match on subject and description (LIKE with escaped wildcards). SQLite folds only ASCII case, so the app registers `ulower()` (Ruby's Unicode `downcase`, `config/initializers/sqlite_functions.rb`) and searches compare `ulower(column)` with a downcased pattern; Bulgarian text matches regardless of case |
| `sort` | `updated` (last activity first, default), `created` (newest first), `priority` (urgent first, then last activity) |

Unknown values are ignored (treated as not given). The filter form is a
plain GET form that applies as soon as a select changes (JavaScript, a
Turbo visit that replaces the history entry); there is no "Apply" button.
Only browsers without JavaScript get one, inside `<noscript>`. The form
carries the view and the search text as hidden fields, so changing a
filter keeps the search. A select with a value other than "Any" is
highlighted in yellow paper, so the active filters are visible at a
glance. "Clear filters" keeps only the view.

### Search

The search field is in the menu bar on every page (ui.md), for staff and
requesters. It is a GET form to `/tickets` that submits on Enter; clearing
it with the field's own clear button shows the list without search again.

- On a ticket list it searches within the current list: it carries the
  view, filters and sort as hidden fields (not the page, a new search
  starts at page 1).
- On any other page it searches `view=all`, so a done ticket is found
  by its number too.
- The field shows the current search text on a ticket list.

### Table

Columns: number, subject, requester, organization, status, priority,
assignee, last activity. Each row is one line (operator, 2026-10-27: the
requester's name under the subject made rows two lines tall): the
requester has its own column. In windows at least 1024px wide no cell
wraps and the subject takes the space left (at least 12em), ending in an
ellipsis when it does not fit; the ticket page shows it in full (no
hover tooltip, operator 2026-10-27; mobile.md rule 4).
Narrower windows hide the requester column and let cells wrap so the
table fits without scrolling sideways (the requester is on the ticket
page); under 760px organization, priority, assignee and last activity
are hidden too. The whole row is not a link -
the subject is, so keyboard and screen reader users get one clear link per
ticket. Status and priority are pills with text (colour is never the only
signal). Urgent and high priority rows get a coloured left edge. The
assignee has a small round badge with their initials in a paper colour
picked from their user id, so the same person always has the same colour
(the name is next to it; the badge is decorative, `aria-hidden`).

Rows alternate (operator, 2026-10-27: "odd/even colouring for the lists
in queue"): every even row of the queue and of My tickets is a shade
darker than the panel's paper (a translucent black tint, so it works on
every view colour and in the dark theme, where the paper keeps its
colour); hovering a row lightens it as before. The urgent/high edge and
the row borders stay.

Assigning from the queue (tickets.md "Assigning"):

- The assignee cell is a menu button showing the badge and name (or
  "Unassigned") with a caret. It opens a small sticky with one button per
  choice: "Me" first, the other active staff, then "Nobody"; the current
  assignee is marked and disabled. One click assigns.
- Unassigned unsolved tickets show an empty "?" badge (screen readers hear
  "Unassigned") and a one-click "Take" button next to it. Taking over
  someone else's ticket is "Me" in the menu (a Take button on every row
  squeezed the subject column).
- The menu is a `<details>` element. With JavaScript it floats over the
  table under its button (so the table's scroll box does not clip it) and
  closes on a click outside, Escape, scrolling or opening another menu;
  without JavaScript it opens inside the cell.

### Bulk actions

Operator, 2026-10-27: "in search and the queue we need an option for
bulk actions". Staff only; search results are the queue (above), so
they have it too.

- The queue table starts with a check box column: one per row
  (`numbers[]`, "Select #1001" for screen readers) and one in the head
  that selects every row of the page. Rows are selected in place; the
  check box cell is padded to a 44px target on phones.
- **Bulk bar** above the table, shown once at least one row is selected
  (always shown without JavaScript): "3 selected", and three selects,
  each starting at "no change": Status (every status), Priority (every
  priority), Assignee ("Me", "Nobody", the staff who may be assigned in
  the user's organizations), then "Apply" and "Clear", and "Delete"
  (with a confirmation; a soft delete, tickets.md "Deleting").
- When every row of the page is selected and the list has more, the bar
  offers "Select all 94 in this list"; then the action applies to every
  ticket of the current view, filters and search (`scope=list`), at most
  500, and the bar says "All 94 in this list selected".
- `PATCH /tickets/bulk` with `numbers[]` or `scope=list` plus the list's
  `view, status, priority, assignee, organization, q`, the changes, and
  `return_to` (a `/tickets` path; anything else goes to `/tickets`).
  Each ticket goes through `Ticket.visible_to`, `TicketPolicy#update?`
  and `apply_changes`, one by one, so events, notifications and live
  refreshes are as for single changes. A ticket where a change is not
  allowed (a status transition, an assignee who may not work that
  organization) is skipped; the rest are changed. A ticket that already
  has the chosen values is left alone. The flash says how many were
  changed and lists up to ten skipped references with the reason.
- Nothing chosen (all "no change") or nothing selected: nothing happens
  and the flash says so.
- The API has the same: `PATCH /api/v1/tickets/bulk` (api.md).
- A selection holds back live refreshes of the list (a checked box is
  work in progress, timeline.md), so it is not lost.

## My tickets (requester)

Tabs: `open` (new, open, pending, postponed; default, yellow), `done`
("Done"; green), `all` (gray), all three of the requester's own tickets
(the only tickets a requester sees, roles.md; the "My organizations"
tab of the same morning was removed on 2026-10-27), each with a coloured
count; the current tab
and the list panel take the tab's colour. Search (`q`, same matching as
above) is the menu bar search. A "New ticket" button. Table columns: number, subject, organization (only if they belong to more than one),
status, last activity; one line per row as in the queue.

Empty states say what to do next ("You have no open tickets. Need help?
Open a new ticket.").

## Live updates

Operator, 2026-10-26: "the queue should refresh live too". An open ticket
list (`/tickets`, the start page) reloads itself within about a second
when tickets change, keeping its view, filters, page (the URL) and scroll
position:

- **Staff queue:** stream `[:queue, :staff]`, told after every ticket
  event (new tickets, replies, notes, status, priority, assignee,
  sharing).
- **My tickets:** stream `[requester, :tickets]` of each requester, told
  after non-internal events of their own tickets (a new ticket, public
  replies, status changes); internal changes send nothing to requesters.
- `TicketListsChannel` accepts the staff stream only for staff, a
  requester stream only for its signed-in owner.
- Signal only: `<turbo-stream action="refresh">` (debounced per stream by
  turbo-rails); the list is fetched again over HTTP through
  `Ticket.visible_to`.
- A refresh waits while the page is busy - an assign menu or the
  notification panel is open, a field has focus or typed text (the menu
  bar search) - as on the ticket page (timeline.md), and runs once idle.

## Pagination

25 per page, `page` parameter (1-based, invalid values mean 1), "Previous"
and "Next" links that keep all other parameters, and "Showing 26-50 of 112".

## Acceptance

`test/models/ticket_filter_test.rb` (views, filters, search, sort, pagination) and
`test/controllers/tickets_controller_test.rb` (which list each role gets,
that the own tabs never contain another requester's ticket, and that the
organization tab contains only tickets of the requester's organizations).

## Security Note

Filters only narrow `visible_to`; they never widen it. Search input is bound
as a parameter and LIKE wildcards in it are escaped.
