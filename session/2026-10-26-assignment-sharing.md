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

- Plan item 6 done, plan complete: clickable task lists for editors
  (`data-task-line` from source positions, enabled by JS, Turbo fetch
  PATCH `.../task`, server checks the rendered task lines so code blocks
  are refused, `edit(group: true)` keeps one revision per 10-minute
  series, saved ticks reset `defaultChecked` so live refreshes are not
  held). Checked in headless Chrome: tick saved without reload, kept
  after reload, marked edited, one new earlier version for two clicks.
- Next: nothing open from the plan; operator items remain (deploy with
  the AddSharingToTickets, CreateNotifications, AddEditing and
  AddMarkdownToMessages migrations, `upgrade=websocket`, SMTP).

- Shared page width and g0no-style editing (operator: shared tickets
  should scale, the widen button was not found, g0no's editing is
  stylish): a later `.ticket-page` rule had kept two columns on shared
  pages (messages narrower than the header); now one 820px column, full
  desk when wide. Width box also in the original request's title strip
  (`partials/_width_box`). In-place fields are borderless on the paper
  with a dashed rule, small buttons, "Ctrl+Enter saves, Esc cancels".
  Checked in headless Chrome: shared page 820 -> 1568px with the box,
  restyled form, Ctrl+Enter saved.

- Request as one note (operator: header and original request as one
  note, bold number before the subject, no "Queue" crumb): the request
  sticky is the grid's head area with `tickets/_note_heading` (h1
  "#1001 Subject", pills) inside the edit frame; the side column spans
  both rows; under 900px the note comes first, then the side panels.
  Same note on shared pages. The edit form keeps the number before the
  subject at the heading's size. Checked in headless Chrome at 1280px,
  390px, editing and the shared page.

- README screenshots refreshed with `make screenshots` against a scratch
  server with the demo data (queue with row shading, ticket page with the
  request note and title strips, requester phone view in Bulgarian, admin
  users in the dark theme); scratch data removed afterwards.

- Production deploy (operator: "deploy to production"): database copied
  with VACUUM INTO to `~stopan/backups/pre-deploy-e553a58.sqlite3`, then
  `DEPLOY_HOST=<server> make deploy` shipped fa69269; five additive
  migrations ran; verified schema, health, headers, sign-up closed,
  loopback-only listener and g0no. Still open: `upgrade=websocket` on
  the Apache proxy line (WebSocket 404, so no live updates in
  production yet) and SMTP.

- WebSocket proxy (operator: "add upgrade=websocket through the
  ISPConfig API"): saved the site record, `sites_web_domain_update`
  changed only the ProxyPass line (passing the current log_retention and
  pm_* values, which the method would otherwise reset to defaults);
  ISPConfig regenerated the vhost in ~50 s and restarted Apache (a few
  seconds down for every site). `/cable` now upgrades with 101, foreign
  origins get 404; Stopan and g0no answer. Live updates work in
  production. Still open: SMTP.

- Organizations: own SMTP, mailbox and public form (operator; decisions:
  IMAP polling, address = identity, magic links, form off by default),
  in five commits: encryption keys from SECRET_KEY_BASE and
  TRUSTED_PROXIES; admin Mail panel (encrypted write-only passwords,
  private hosts refused, test email) and per-organization routing in
  ApplicationMailer (also Devise's parent; without global SMTP only
  organizations with SMTP send); magic sign-in links (button + POST so
  prefetching scanners do not use them, one use, 24 h, requesters only,
  "email me a link", first password without the current one); public
  page /support/<slug> (rate limits, honeypot, signed form time, same
  answer for every address, confirmation with a link); IMAP poller in
  the web process (MAILBOX_POLLING), mail to tickets and replies with
  loop protection and quote stripping. Found in the browser: a new
  requester's mails were in English, now the page's language is kept.
  Not tested against a real IMAP server (fake server in tests only).
- Admin impersonation (operator: "admin to have option: impersonate"):
  agents and requesters only, bypass_sign_in, red banner with the way
  back, account page locked, records with IP on the user's admin page.
- Process slip: one commit (2824094) was made after a flaky make check
  failure (SQLite lock in parallel tests); the rerun passed with the same
  code. Commits now run only as `make check && git commit`.
- Next: deploy when the operator asks (migrations AddMailSettings...,
  AddPasswordChosen..., AddPublicFormAndSources, CreateImpersonations),
  then set TRUSTED_PROXIES and MAILBOX_POLLING in stopan.env and try a
  real mailbox.

- Flash messages (operator: slide in from the right, stay in the centre
  band under the menu bar, sweep out to the left): the stack is now in
  the page flow at the top of the desk, centred, 560px; slide-in from the
  right, sweep to the left, then the band collapses; clipped sideways;
  no movement with reduced motion. Checked in headless Chrome: left 613
  while sliding, 360 centred at 1280px, -840 while leaving, heading moved
  up from 132 to 68 after, no horizontal scroll.

- Assignee in the request note (operator: "next to In progress add who
  is working on the ticket"): "Assigned to" with the initials badge and
  name after the pills, for staff, requesters and shared pages (sharing.md
  updated: staff names already show on public replies; assignee changes
  stay internal events). Checked at 1280px and 390px in Bulgarian.

- Admin users list (operator): pencil and "sign in as" icon buttons
  (confirm kept for impersonation), Sign-ins column from sign_in_count.
- Notices pass the left window edge (operator): the leave transition never
  ran (the filled entry animation overrode it), now a flash-out
  animation, no fade, band as wide as the window. Measured 616 -> 274 ->
  -486 px while leaving.
- Messages from administrators (operator: "send messages to users, shown
  in Notifications"): /admin/messages/new to one user (envelope icon in
  the users list), a role, an organization's members (button on its
  page) or everyone active, never the sender; stored as notifications of
  kind message (ticket_id nullable, message text, check constraint), live
  signal, own page when opened. Migration AddMessageToNotifications.
  Checked in headless Chrome: count hint, confirm, bell, message page.

- Public page link easy to copy (operator): `_public_link` partial
  (read-only field, Copy link, Open in a new tab) on the organization page
  and in the edit form's public page part (saved URL name, note when off);
  one-click copy icon (`data-copy-value`) next to organizations with the
  page on in the list. Checked in headless Chrome: both copies put the URL
  on the clipboard and show "Copied".

- Organization members (operator: every member gets a notification for
  new tickets of their organization; chose that members can read them,
  in the app only): Ticket.visible_to for requesters is now every ticket
  of their organizations (public part); replying, resolving, editing and
  sharing stay with the ticket's requester (403 for colleagues, 404 for
  other organizations, tests updated); "My organizations" tab with the
  requester under each subject; [organization, :tickets] list streams;
  TicketNotifier stores in-app "created" notifications for active
  members (no email). Checked in headless Chrome: Anna's new ticket
  raised Boris's bell 1 -> 2 and appeared in his tab live; the colleague
  page has no composer and says who can reply.

- Kanban board like fizzy.do (operator): a web-fetch agent read Fizzy's
  site and help guide, and I looked at their board screenshot (not kept
  in the repo). /tickets/board for staff: columns per status in status
  colours, Resolved/Closed collapsed into tall pills with count and
  vertical label (expansion remembered in localStorage), white cards with
  a coloured strip (#number | ORGANIZATION, priority), big title,
  created/updated, requester -> assignee badges, urgent cards golden and
  on top, 50-card limit for solved columns; drag and drop to allowed
  transitions (others dimmed) via PATCH /tickets/:number/move (204/422
  JSON, redirect for the Move menu form); List | Board switch; live via
  the queue stream; JSON 403 without a template. Checked in headless
  Chrome: drag of #1005 New -> In progress kept after reload, counts
  updated, Move menu, phone scrolls inside the board.

- Requesters without an organization see nothing (operator):
  `require_organization` before action redirects them to /no-organization
  (403 for JSON), menu bar empty, no notification stream; Devise pages,
  sign-out, preferences, shared pages and an admin's way back from
  impersonation stay allowed; admin messages skip them. Staff are not
  affected (said so to the operator). Checked in headless Chrome.

- Not now, automatic postponing, board scrolling, allowed senders
  (operator): postponed status (purple, own queue view, requester Open
  tab, no email); /admin/settings with auto_postpone_days (hourly in the
  web process, rake stopan:postpone_inactive, stamp on cards due within 7
  days, note on the ticket page); board spans the window, fits its height,
  columns scroll on their own, edge scrolling while dragging, empty
  columns start collapsed; organizations.public_allowed_senders
  (addresses or @domains, empty = anyone) checked by the public form.
  Found while checking: organization attribute labels (slug, intro) had
  landed under app_setting in the locales; fixed. Stages still to do.

- Stages (operator, third proposal): `stages` table and tickets.stage_id
  (FK, nullify on delete); admin settings list per status with rename,
  colour, up/down, delete and a new-stage form; board columns right after
  their status ("In progress / Investigating", keys kept per browser);
  drag between status and stage columns (same status allowed both ways)
  and the Move menu post status + stage; internal stage_changed events
  with names; a status change clears another status's stage; Stage select
  in Properties and "· Investigating" in the queue for staff; requesters
  never see stages. Stamp wording "Not now / today" for due cards.
  Checked in headless Chrome: stage columns, drag into QA kept after
  reload, stamps on cards 3 days and today away.

- Agents scoped to their organizations (operator): Ticket.visible_to
  gives all only to admins; agents without a membership get the
  no-organization notice; assignable staff = admins + the ticket
  organization's agents (validation, assign menus, Properties, filters);
  agents create tickets only in their organizations; org filters list
  only theirs; mailbox replies from agents outside the organization are
  ignored. Demo: Maria in both organizations, Petar in Globex. Test
  fixtures make both test agents members of both organizations.
  Operator must add production agents as members before deploying.
- Board: columns sit centred when they need less than the window width
  (auto margins on the first and last column, so an overflowing board
  still starts at its first column); clicking an expanded column's header
  collapses it, as clicking a pill expands it.
- One "Done" status ("Готова") replaces resolved and closed (operator
  chose "one Done status everywhere"). Transitions: new/open/pending/
  postponed -> done, done -> open. No final close: requesters reply to a
  done ticket (page or email) and it reopens; staff reply without
  reopening. Queue and My tickets view `done` (old `solved` falls back to
  the default view); board has one collapsed Done column (50 cards).
  `done_at` replaces `resolved_at`/`closed_at`. Migration
  `MergeResolvedAndClosedIntoDone` converts tickets, status events,
  notifications and stages; resolved -> closed events are deleted (they
  would read "Done to Done"). Irreversible.
- Board filters are now the list's: status, priority, assignee,
  organization and sort, rendered by the shared partial
  `tickets/_filters` (queue and board), keeping the search `q`. A status
  filter shows only that status's columns; sort orders cards after the
  golden ones (`TicketFilter#order` is now public); the "more in the
  list" link carries the filters.
- README screenshots refreshed with `make screenshots` against a scratch
  database with the `make demo` data (removed afterwards); a fifth one,
  `board.png`, shows the board; specs/ui.md "Screenshots" lists five.
- The menu bar marks "Queue" on the board as well (`current_section`
  counts the boards controller as :tickets); `board.png` retaken with the
  demo tickets aged 25 minutes so card times fit on one line.
- Ticket lists are one line per row (operator did not like the requester
  under the subject): queue and "My organizations" have a Requester
  column; from 1024px no cell wraps and the subject ends in an ellipsis
  (tooltip has it whole, min 12em); under 1024px the requester column is
  hidden and cells wrap, so the table never scrolls sideways (checked at
  1280, 1024, 1023, 900, 800 and 390px, en and bg). README `queue.png`
  retaken.
- Language choice (operator: "make it easy to change the language from
  the profile or the header"): a BG/EN button after the text sizes
  (`PATCH /preferences`, `locale`, full reload) and a Language select on
  the account page ("Browser language", English, Български;
  `PATCH /users/language`, `Users::LanguagesController`). Order: the
  user's `users.language` (new column, migration `AddLanguageToUsers`),
  the `locale` cookie, Accept-Language, English; while impersonating the
  cookie comes first and the user's choice is never changed. A choice
  also sets `users.locale`, which the browser then no longer overwrites,
  so emails follow it. `test/integration/language_test.rb`.
- Menu bar: it ran off the screen between 561 and about 900px already
  (up to 240px for an admin in Bulgarian); under 960px it now wraps with
  the search on its own row. Measured 0px overflow at 561-1280px for
  requester, agent and admin in en and bg.
- Production 404 again (operator): ModSecurity CRS blocked replies in
  Bulgarian (941310 reads UTF-8 Cyrillic bytes as < >), board moves and
  task boxes (911100, PATCH) and the Accept-Charset header (920450); the
  403 page was proxied to Rails, hence 404. App: scripts send POST with
  `_method=patch`. Site: SecAction 13183 also drops 941310 and
  accept-charset, plus `ProxyPass /error/ !` (specs/deploy.md
  "ModSecurity false positives"; `deploy/ispconfig-site.json`).
  Applied on request (Remote API, record saved first; Cyrillic POST now
  422 from Rails, blocks show a real 403), then deployed cbf319b after a
  backup (`pre-deploy-3e50793.sqlite3`); checks in specs/deploy.md.
- German UI (operator: "add German"): `de.yml`, `devise.de.yml`,
  `rails.de.yml` (translated by a subagent from en.yml / rails.bg.yml,
  formal "Sie"; keys and placeholders checked by script, plus
  `current_password`/`remember_me` added by hand). The header shows one
  button per other language ("BG DE" on English pages). The menu bar now
  wraps under 1024px (a German admin needed about 985px); swept 561-1280px
  for all roles in en/bg/de with no overflow.
  `test/integration/german_pages_test.rb` renders every staff, requester
  and public page in German (missing translations raise in tests) and
  checks the German reset and ticket emails.
- Menu bar role is an icon instead of the word (operator): person /
  headset / shield (`role_icon`, new `headset` and `shield` icons), name
  as tooltip and aria-label; shown at every width now that it is small.
- Deployed 8f4eb97 (German, role icon) after a backup
  (`pre-deploy-cbf319b.sqlite3`); no migrations; checks in specs/deploy.md.
- Header language buttons now only for visitors who are not signed in
  and on shared ticket pages (also when signed in); signed-in users use
  the account page (operator). `language_switch?` helper.
- Translate button (operator chose DeepL): spec written,
  specs/translation.md; not built yet.

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

- Production runs cbf319b (2026-10-27). If users still see 403/404 on
  some action, read the site's Apache error log for the ModSecurity rule
  id first (specs/deploy.md "ModSecurity false positives").

- Refresh the README screenshots (`make screenshots`, specs/ui.md) when
  the queue, board, ticket or admin users page changes visibly.

- Still to set in `stopan.env` when the operator wants: SMTP,
  `TRUSTED_PROXIES`, `MAILBOX_POLLING`.

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
