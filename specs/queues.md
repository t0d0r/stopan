# Ticket lists: agent queue and "My tickets"

Both are `GET /tickets` (`TicketsController#index`), which is also the
start page (`/`). Staff get the queue; requesters get "My tickets". Every
list query starts from `Ticket.visible_to(current_user)`.

## Agent queue (staff)

Layout: a column of views on the left (a row of tabs under 760px), the
filter bar and the table on the right.

### Views (`view` parameter)

| view | tickets | default |
|------|---------|---------|
| `unsolved` | new, open, pending | yes |
| `mine` | unsolved and assigned to me | |
| `unassigned` | unsolved and without assignee | |
| `pending` | pending | |
| `solved` | resolved, closed | |
| `all` | every ticket | |

Each view shows its count.

### Filters (combined with the view, all optional)

| parameter | values |
|-----------|--------|
| `status` | one status |
| `priority` | one priority |
| `assignee` | a staff user id, `me`, or `none` |
| `organization` | an organization id |
| `q` | search text: `#1001` or `1001` also matches the ticket number; otherwise case-insensitive substring match on subject and description (LIKE with escaped wildcards) |
| `sort` | `updated` (last activity first, default), `created` (newest first), `priority` (urgent first, then last activity) |

Unknown values are ignored (treated as not given). The filter form is a
plain GET form; selects submit on change with JavaScript, and an "Apply"
button works without it. "Clear filters" keeps only the view.

### Table

Columns: number, subject (with requester name under it), organization,
status, priority, assignee, last activity. The whole row is not a link -
the subject is, so keyboard and screen reader users get one clear link per
ticket. Status and priority are pills with text (colour is never the only
signal). Urgent and high priority rows get a coloured left edge.

## My tickets (requester)

Tabs: `open` (new, open, pending; default), `solved` (resolved, closed),
`all`, each with a count; search box (`q`, same matching as above); a
"New ticket" button. Table columns: number, subject, organization (only if
they belong to more than one), status, last activity.

Empty states say what to do next ("You have no open tickets. Need help?
Open a new ticket.").

## Pagination

25 per page, `page` parameter (1-based, invalid values mean 1), "Previous"
and "Next" links that keep all other parameters, and "Showing 26-50 of 112".

## Acceptance

`test/models/ticket_search_test.rb` (views, filters, search, sort) and
`test/controllers/tickets_controller_test.rb` (which list each role gets,
and that a requester's list never contains another requester's ticket).

## Security Note

Filters only narrow `visible_to`; they never widen it. Search input is bound
as a parameter and LIKE wildcards in it are escaped.
