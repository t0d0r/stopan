# 2026-10-26 - quick assignment, requester organizations, sharing

Operator requests, in order:

1. "Easy and fast taking or changing of the assignee."
2. "Do not show organizations to users who are not part of them" - read as
   the staff new ticket form: the organization select should list only the
   chosen requester's organizations.
3. "Tickets can be shared, like in g0no" - next, spec first.

## Done

- Spec: specs/tickets.md "Assigning" and "Creating" (requester
  organizations), specs/queues.md (assign menu, Take), specs/ui.md (Take on
  the ticket page).
- `PATCH /tickets/:number/assign` (`TicketsController#assign`, staff only):
  `assignee_id` = active staff id or blank. Taking a `new` ticket
  yourself also sets it to `open` ("In progress"). Invalid assignee ->
  alert, nothing changes. Redirects back to a same-host Referer (the queue
  keeps view, filters and page), else the ticket.
- Queue: assignee cell is a `<details>` menu (Me first, other staff,
  Nobody; current one disabled with a check). JS floats the menu with
  `position: fixed` so the table's scroll box does not clip it, one open at
  a time, closes on outside click, Escape (focus back), scroll and resize.
  Unassigned unsolved tickets show a dashed "?" badge and a "Take" button.
  A Take button on every row squeezed the subject column, so taking over
  someone else's ticket is "Me" in the menu.
- Ticket page: "Take" above the properties form for staff when the
  unsolved ticket is not theirs.
- New ticket (staff): requester options carry `data-organizations`; JS
  hides and disables the other organizations, selects the only one,
  disables the select until a requester is chosen and swaps the hint.
  The server check (requester must be a member) still decides.
- bin/screenshots: `Network.enable` before `Network.setExtraHTTPHeaders`;
  without it Accept-Language was never sent and the "Bulgarian" README
  screenshot was English. Screenshots refreshed.

## Decisions

- Assign menu instead of auto-submitting selects: a keyboard arrow on a
  closed select fires `change` on some systems, which would reassign (and
  email) by accident; buttons need an explicit click.
- The assignee column is hidden under 760px, so on phones assignment is on
  the ticket page (Take or the properties form).

## Files

specs/tickets.md, specs/queues.md, specs/ui.md, config/routes.rb,
app/controllers/tickets_controller.rb, app/views/tickets/{_assign_menu,
_take_button,_queue,_properties,new}.html.erb,
app/assets/{javascripts/application.js,stylesheets/application.css},
config/locales/{en,bg}.yml, test/controllers/{assignments,tickets}_controller_test.rb,
bin/screenshots, docs/screenshots/*.png.

## Verify

`make check`; `make run`, open /tickets as an agent and use the assignee
menu and Take; open /tickets/new and pick a requester.

## Next

Ticket sharing by link (like g0no's note sharing): write specs/sharing.md
first - who may share, what a shared page shows (never internal notes or
internal events), optional password, revocation, rate limits.

## Security Note

Assignment is staff only (403 for requesters) and only active staff can
be assignees; the redirect back follows only same-host referers
(`allow_other_host: false`), so it cannot be used as an open redirect. The
organization filter in the form is a convenience; the server-side
membership check is what protects the data.
