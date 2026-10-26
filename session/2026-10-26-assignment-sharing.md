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

- Sharing (specs/sharing.md, modelled on g0no's note sharing):
  - `tickets.share_token` (unique), `share_password_digest`, `shared_at`;
    `Ticket#share!` / `#unshare!` write with `update_columns` (no
    `updated_at` bump) and record internal `shared` / `unshared` events;
  - `TicketSharesController` (POST/DELETE `/tickets/:number/share`):
    staff, or the requester for their own ticket (`TicketPolicy#share?`);
  - `SharedTicketsController` at `/s/:token`: requester view only
    (description, public replies, non-internal events; no priority,
    assignee, organization or emails), password form with a session
    unlock fingerprint, rate limit 10 per 5 minutes per token, files of
    the ticket and public replies only, private headers;
  - Sharing panel on the ticket page (copy link, stop, new link), link
    icon in ticket lists, "Sharing" panel on the admin dashboard;
  - `FileSending` concern shared by both attachment controllers.

- Notification panel (operator: "let there be a notification panel"):
  `notifications` table; `TicketNotifier#deliver_later` stores one row per
  recipient next to the email (same recipients, kinds and checks); bell
  with unread count in the menu bar, `<details>` dropdown with the 8
  newest, `/notifications` page (50 per page), `GET /notifications/:id`
  marks read and jumps to `#event-<id>`, opening a ticket marks its
  notifications read, "Mark all as read"; rows show kind, actor, new
  status, ticket number and subject - never reply or note text;
  `Notification.visible_to` re-checks ticket visibility and hides `noted`
  from non-staff; 200 newest kept per user. Under 560px the panel spans
  the screen under the menu bar.

- Live notification panel (operator: "make live updates of the
  notifications"): `ApplicationCable::Connection` accepts only signed-in,
  active users (Warden); layouts subscribe with `turbo_stream_from
  current_user, :notifications`; `Notification.broadcast_changed` sends a
  content-free `notifications_refresh` Turbo Stream after a notification
  is created and after reads (`Notification.mark_read`); `application.js`
  registers the custom action, coalesces signals (300 ms), waits while
  the panel is open and swaps in `GET /notifications/panel`. Checked end
  to end in headless Chrome: an agent's reply posted from another session
  moved the requester's bell from 0 to 1 without a reload.

- Queue views moved from the left column to a horizontal tab row under
  the title (operator: "like the admin menu"); the list panel is full
  width; under 760px the row scrolls sideways and scrolls the current view
  into sight. README screenshots refreshed.

- Shared page live refresh (operator: "the shared ticket does not
  refresh"): `/s/:token` subscribes to `Ticket#share_stream` (ticket,
  :share, SHA-256 of the token) with `turbo-refresh-scroll` preserve;
  non-internal `TicketEvent`s broadcast a debounced Turbo `refresh` after
  commit, and replacing or stopping the link refreshes the old token's
  stream. Visitors are anonymous, so `ApplicationCable::Connection` no
  longer rejects them (current_user is nil); the notification stream moved
  to `NotificationsChannel`, which accepts only its signed-in owner.
  Checked in headless Chrome: an anonymous shared page showed a new agent
  reply without a reload; the bell still updates live.

- Ticket page live refresh (operator: "the ticket page should refresh
  live too"): two streams per ticket, `[ticket, :page, :staff]` (every
  event) and `[ticket, :page, :public]` (non-internal events), so a
  requester's page gets no signal for internal notes; `TicketsChannel`
  re-checks `Ticket.visible_to` and staff-ness on subscribe
  (`ApplicationCable::OwnStream` shared with `NotificationsChannel`);
  `TicketEvent` after commit calls `Ticket#refresh_pages`. In the browser
  a refresh waits while the page is busy (typed text, changed select,
  chosen file, focused field, open menu or dialog) and shows a notice;
  a select without a `selected` attribute counts as unchanged on its
  first option (that bug made every page look busy). Checked in headless
  Chrome: idle page updated, typing kept the draft and showed the notice,
  clearing the draft let the refresh run.

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

- Sharing: requesters may share their own tickets (they own the
  conversation); the rate limit key is the token, not the IP, because the
  production client IP is not confirmed yet; a shared page shows no
  organization name, so an outsider learns as little as possible.

## Next

- Rebuild the Docker image (`make docker-up`) to see the changes on :3000;
  production needs a deploy by the operator (migration
  `AddSharingToTickets`).
- Sharing later: expiry dates, view counts (todo).
- Production: the next deploy runs the `AddSharingToTickets` and
  `CreateNotifications` migrations; the Apache vhost needs
  `upgrade=websocket` for live panel updates (todo, operator).

## Security Note

Sharing makes ticket text readable without sign-in: only the public part is
ever rendered (tests assert no internal note text, emails, organization or
internal events), tokens are 32 base58 characters, replaced links die at
once, and the token appears in access logs because it is in the path.

Assignment is staff only (403 for requesters) and only active staff can
be assignees; the redirect back follows only same-host referers
(`allow_other_host: false`), so it cannot be used as an open redirect. The
organization filter in the form is a convenience; the server-side
membership check is what protects the data.
