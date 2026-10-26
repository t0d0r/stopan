# 2026-10-26 - ticket list look

Operator request: make the ticket list (`/tickets`) colourful, move the
search into the header, and let the filters work without the Apply button.

## Done

- Specs first: specs/queues.md (view colours table, filter form without
  Apply, new "Search" section, assignee badges, requester tab colours) and
  specs/ui.md (menu bar search, coloured panels, flash position on phones).
- Colour:
  - every view has a paper colour (unsolved yellow, mine purple,
    unassigned pink, pending blue, solved green, all gray; requester
    open yellow, solved green, all gray), shown as a square and a coloured
    count; the current view is a small sticky; the list panel takes the
    view's colour (`TicketsHelper#view_color`);
  - assignees get a round initials badge in a colour picked from the user
    id (`TicketsHelper#user_avatar`, aria-hidden, name next to it);
  - a filter select with a value is highlighted in yellow paper
    (`.select.is-set`);
  - row hover tint.
- Search: `partials/_search.html.erb` in the menu bar for signed-in users,
  role=search, GET /tickets, input id `menubar-q`. On a ticket list it
  carries the view, filters and sort as hidden fields (not the page);
  elsewhere `view=all` (`ApplicationHelper#search_scope_params`). Removed
  the search fields from the queue filter bar and from "My tickets"
  (and the unused `ui.my_tickets.search_label` key). Clearing the field
  with its x button submits only when a search was shown.
- Filters: no Apply button; selects submit on change (existing JS); a
  `<noscript>` Apply button for browsers without JavaScript; the filter
  form keeps `q` as a hidden field.
- Layout: menu bar nav no longer wraps at ~800px, role label hidden under
  900px, search on its own full-width row under 560px, flash notices at
  the bottom under 560px.
- README feature list and the four screenshots refreshed (taken from a
  throwaway dev server on a scratch database with the demo data; nothing
  from it is kept).

## Decisions

- "Header" = the menu bar, so search is reachable from every page, as in
  g0no's original menu bar search.
- Search does not search as you type: Turbo replaces the body and the field
  would lose focus; Enter is enough.
- Admin users list keeps its Apply button for now (todo item).

## Files

specs/queues.md, specs/ui.md, README.md, docs/screenshots/*.png,
app/helpers/{application,tickets}_helper.rb, app/views/partials/_search.html.erb,
app/views/layouts/application.html.erb, app/views/tickets/_{queue,my_tickets}.html.erb,
app/assets/stylesheets/application.css, app/assets/javascripts/application.js,
config/locales/{en,bg}.yml, test/controllers/tickets_controller_test.rb.

## Verify

`make check` (rubocop, brakeman, gitleaks, tests). `make run` and open
/tickets. The Docker container on port 3000 shows the change only after
`make docker-up` rebuilds the image.

## Next

- Same auto-applying filters for the admin users list (todo).
- Roadmap: auto-close resolved tickets (needs a scheduler; with Solid
  Queue).

## Security Note

The menu bar search is a plain GET to /tickets: the query goes through the
same `Ticket.visible_to` scope and escaped LIKE pattern as before, and the
hidden fields only carry values the filter already validated. Search text
appears in URLs and server logs, as before; do not paste secrets into it.
