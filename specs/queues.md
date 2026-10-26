# Ticket lists: agent queue and "My tickets"

Both are `GET /tickets` (`TicketsController#index`), which is also the
start page (`/`). Staff get the queue; requesters get "My tickets". Every
list query starts from `Ticket.visible_to(current_user)`.

## Agent queue (staff)

Layout: a column of views on the left (a row of tabs under 760px), the
filter bar and the table on the right. The search field is in the menu bar
(see "Search" below).

### Views (`view` parameter)

| view | tickets | default |
|------|---------|---------|
| `unsolved` | new, open, pending | yes |
| `mine` | unsolved and assigned to me | |
| `unassigned` | unsolved and without assignee | |
| `pending` | pending | |
| `solved` | resolved, closed | |
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
| `solved` | green (as the resolved status) |
| `all` | gray |

### Filters (combined with the view, all optional)

| parameter | values |
|-----------|--------|
| `status` | one status |
| `priority` | one priority |
| `assignee` | a staff user id, `me`, or `none` |
| `organization` | an organization id |
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
- On any other page it searches `view=all`, so a closed ticket is found
  by its number too.
- The field shows the current search text on a ticket list.

### Table

Columns: number, subject (with requester name under it), organization,
status, priority, assignee, last activity. The whole row is not a link -
the subject is, so keyboard and screen reader users get one clear link per
ticket. Status and priority are pills with text (colour is never the only
signal). Urgent and high priority rows get a coloured left edge. The
assignee has a small round badge with their initials in a paper colour
picked from their user id, so the same person always has the same colour
(the name is next to it; the badge is decorative, `aria-hidden`).

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

## My tickets (requester)

Tabs: `open` (new, open, pending; default, yellow), `solved` (resolved,
closed; green), `all` (gray), each with a coloured count; the current tab
and the list panel take the tab's colour. Search (`q`, same matching as
above) is the menu bar search. A "New ticket" button. Table columns: number, subject, organization (only if
they belong to more than one), status, last activity.

Empty states say what to do next ("You have no open tickets. Need help?
Open a new ticket.").

## Pagination

25 per page, `page` parameter (1-based, invalid values mean 1), "Previous"
and "Next" links that keep all other parameters, and "Showing 26-50 of 112".

## Acceptance

`test/models/ticket_filter_test.rb` (views, filters, search, sort, pagination) and
`test/controllers/tickets_controller_test.rb` (which list each role gets,
and that a requester's list never contains another requester's ticket).

## Security Note

Filters only narrow `visible_to`; they never widen it. Search input is bound
as a parameter and LIKE wildcards in it are escaped.
