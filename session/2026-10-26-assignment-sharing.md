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

- Ticket lists live refresh (operator: "the queue should refresh live
  too"): `/tickets` subscribes through `TicketListsChannel` to
  `Ticket.list_stream(user)` - `[:queue, :staff]` for staff (every
  event) or `[requester, :tickets]` (non-internal events of their own
  tickets); `Ticket#refresh_pages` broadcasts to them. The busy check
  holds a refresh while an assign menu is open. Checked in headless
  Chrome: idle queue refreshed after a reply; with the assign menu open
  it waited and refreshed once the menu closed.

- Admin pages live refresh (operator: "the admin pages should refresh
  live too"): stream `[:admin]` through `AdminChannel` (administrators
  only); `RefreshesAdminPages` concern on User, Organization and
  Membership broadcasts after commit, and `Ticket#refresh_pages` does too
  (dashboard counts); the layout subscribes and sets refresh scroll
  preserve on admin pages (`live_admin_page?`). Checked in headless
  Chrome: the users list refreshed after another user signed in and
  replied; a half-typed new user form waited and kept its text.

- Notifications page live refresh (2026-10-27, operator: "the
  notifications page should refresh live too"): no new stream; on
  `/notifications` (`data-notifications-page`) the coalesced
  `notifications_refresh` signal runs a local Turbo page refresh instead
  of the panel fetch, with scroll preserve and the usual busy wait. The
  signal now carries `request-id` (`Turbo.current_request_id`), so the
  tab's own "Mark all as read" does not reload again and drop its notice.
  Checked in headless Chrome: the page refreshed after a reply; after its
  own "Mark all as read" it kept the notice and did not reload; with the
  bell panel open it waited and refreshed once the panel closed.

- Attachment preview (2026-10-27, operator: "attached files in a
  previewable format should be previewed"): g0no's preview dialog
  (image, PDF iframe, text in `<pre>`, previous/next, Download) on the
  ticket page and the shared page; inline routes
  `/tickets/:number/attachments/:id/preview` and
  `/s/:token/files/:id/preview` reuse the download lookups;
  `Attachable.preview_kind`; CSP sandbox on images and text,
  `default-src 'none'; frame-ancestors 'self'` on PDFs (Chrome refuses a
  sandboxed PDF; the app policy forbids framing). Checked in headless
  Chrome: PNG, PDF viewer, text and "no preview" for ZIP on both pages,
  arrow keys and Escape.

- Live viewer count of shared links (2026-10-27, operator: "show how
  many are viewing a shared document now, like a shared Google
  document"): `SharedTicketChannel` replaces the default channel on the
  shared page (only the current link's stream, ticket number as param),
  counts subscriptions per link digest in `ShareViewers` (process memory)
  and broadcasts `share_viewers` with only the count to the share stream
  and the ticket page streams; the shared page shows "Only you are
  viewing" / "N people viewing now", the Sharing panel "Nobody / N people
  have the link open now", with a green dot. Checked in headless Chrome
  with several tabs: 0 -> 1 -> 2 -> 1 -> 0 on both pages as tabs opened,
  closed and navigated away.
- Open: counts are per process (fine with the single Puma process and
  the async adapter); several processes would need a shared store.

- Editing the request and replies (2026-10-27, operator: "an option to
  edit replies and original requests"): staff edit any text, a requester
  their own request and own public replies while the ticket is not
  closed; `Editable#edit` keeps the old text in `revisions` (migration
  `AddEditing`, also `edited_at`/`edited_by_id` on tickets and comments),
  no event, email or `updated_at` change; "edited by" marker for
  everyone, "Earlier versions" for staff only; inline form in a Turbo
  frame, save reloads the page with a notice. Checked in headless Chrome:
  requester edited subject and description in place (title, notice,
  marker), agent cancelled and then edited a reply, earlier versions
  listed.

- Plan, not started (operator, 2026-10-27: "see what options g0no has
  for showing notes and apply them, give me a plan"): copy box,
  Markdown per message, double-click to edit, word diff and restore in
  earlier versions, wide view preference, clickable task lists (todo
  "Plan"). Not taken over: per-note colours (colours mean requester,
  staff and internal here), autosave (replies are sent messages), the
  note board and sorting.

- Plan item 1 done (operator: "go in this order"): copy box in the title
  strip of the request, replies and notes, also on shared pages
  (`copy_box`, `[data-message-text]`, `copyText` with execCommand
  fallback). Checked in headless Chrome: the clipboard got the request
  and a note's text, the check mark showed and reset after 1.5 seconds.

- Plan item 2 done: Markdown per message (`markdown` on tickets and
  comments, migration `AddMarkdownToMessages`, gem `commonmarker`),
  check box when writing, "M" box in the title strip for editors (not an
  edit), `MarkdownHelper` with g0no's three safety layers, HTML email
  formatted, text email plain. `redirect_to_ticket` sends Turbo requests
  to the bare page so the refresh keeps the scroll (Turbo drops redirect
  anchors). Checked in headless Chrome: lists, task boxes, quote, table,
  links in a new tab, script dropped; toggling and saving keep the scroll.

- Message title strip (operator: author, role, time and "edited by" into
  the header of the original request): `tickets/_message_bar` for the
  request, replies, notes and shared pages; Edit became a pencil box next
  to the Markdown and Copy boxes. Checked at 1280px (light and dark) and
  390px (wraps, no horizontal scroll).

- Plan item 3 done: double-click on editable text opens the in-place
  form with the caret matched from the visible text before the click
  (white space and Markdown punctuation ignored); Escape cancels an
  unchanged form only; frame-loaded text areas auto-grow. Checked in
  headless Chrome: caret at "sec|ond" in plain text and "bl|ank" inside a
  Markdown table, no scroll, Escape both ways.

- Alternate row shading (operator: "odd/even colouring for the lists in
  queue"): even rows of the queue and My tickets get a translucent dark
  tint, so it suits every view colour and the dark theme.

- Plan item 4 done: earlier versions show each edit word by word
  (`TextDiff` from g0no, `diff_html`, red struck `<del>`, green `<ins>`,
  subject diffs for the request) and staff can "Restore this version"
  (`RevisionsController#restore`, confirm dialog, an ordinary edit).
  Found in the browser: CRLF from text areas made every line a change, so
  descriptions and comment bodies are now stored with LF and diffs treat
  CRLF as LF. Checked in headless Chrome: diff marks, confirm text,
  restore with notice and a new earlier version.

- Plan item 5 done: width switch next to the theme switch (`width`
  cookie, `<html data-width>`, desk 1120px -> 1920px, hidden under 760px,
  generic preference JS). Checked in headless Chrome at 1800px: desk
  1120 -> 1800, kept after reload, back to normal; hidden at 390px.

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
Notifications page live refresh: specs/notifications.md,
app/models/notification.rb, app/views/notifications/index.html.erb,
app/assets/javascripts/application.js,
test/integration/notification_live_updates_test.rb.
Attachment preview: specs/attachments.md, app/models/concerns/attachable.rb,
app/controllers/{attachments,shared_tickets}_controller.rb,
app/controllers/concerns/file_sending.rb, config/routes.rb,
app/helpers/tickets_helper.rb, app/views/partials/_preview_dialog.html.erb,
layout, application.{js,css}, locales, attachment and shared ticket tests,
test/fixtures/files/{dot.png,blank.pdf,notes.zip}.
Viewer count: specs/sharing.md, app/models/share_viewers.rb,
app/channels/shared_ticket_channel.rb, app/models/ticket.rb
(`share_digest`), tickets helper (`share_viewers_tag`), icons (eye),
shared_tickets/show, tickets/_sharing, application.{js,css}, locales,
test/models/share_viewers_test.rb, test/channels/shared_ticket_channel_test.rb,
shared tickets controller test.
Editing: specs/{timeline,tickets,roles,data-model,attachments,sharing}.md,
db/migrate/20261027100000_add_editing.rb, app/models/{revision.rb,
concerns/editable.rb,comment.rb,ticket.rb,user.rb},
app/policies/ticket_policy.rb, app/controllers/{ticket_descriptions,
comments}_controller.rb, ticket_timeline concern, views
(ticket_descriptions/, comments/, tickets/_revisions, _event, show,
shared_tickets/show), helpers, locales, CSS, test/models/revision_test.rb,
test/controllers/edits_controller_test.rb.

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
