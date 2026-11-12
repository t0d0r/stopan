# Todo

## Phase 1 - service desk vertical slice (2026-10-25)

- [x] inspect the g0no baseline; write the service desk spec (specs/README.md)
- [x] rebrand g0no -> Stopan; remove the notes domain, deploy files and import (specs/overview.md)
- [x] fresh migrations: users with roles, organizations, memberships, tickets, comments, ticket events (specs/data-model.md)
- [x] roles, scopes and TicketPolicy with tests (specs/roles.md)
- [x] ticket model: numbering, validations, transitions, events (specs/tickets.md)
- [x] comments, internal notes and the timeline (specs/timeline.md)
- [x] attachments with limits and authorized download (specs/attachments.md)
- [x] agent queue and My tickets with filters, search, pagination (specs/queues.md)
- [x] ticket pages: new, show with properties, composer (specs/tickets.md, specs/ui.md)
- [x] admin: dashboard, users and roles, organizations and memberships (specs/admin.md)
- [x] Devise lockable and user deactivation (specs/auth.md)
- [x] service desk styling, English and Bulgarian translations (specs/ui.md)
- [x] content security policy and log filtering of ticket text (specs/ui.md, specs/overview.md)
- [x] flow tests for lifecycle and visibility (specs/roles.md)
- [x] demo data task, README rewrite (specs/auth.md)
- [x] own account page translated, self-deletion disabled (specs/auth.md)
- [x] Unicode case-insensitive search for Bulgarian text (specs/queues.md)
- [x] screenshots of queue, ticket and admin pages in README, `make screenshots` (specs/ui.md)
- [x] translated Devise password reset and sign-up pages: check every string in bg (specs/auth.md)
- [x] translated password reset email in the request language (specs/auth.md)

## Deployment to stopan.linuxfan.org (2026-10-25, specs/deploy.md)

- [x] production deployment design, quadlet, ISPConfig site parameters, deploy and Remote API scripts (specs/deploy.md)
- [x] ISPConfig remote user `stopan_deploy` (127.0.0.1, Sites Domain functions) and the root-only credentials file (specs/deploy.md)
- [x] system user stopan, subuid range, linger, settings file, quadlet (specs/deploy.md setup 2-3)
- [x] prove port 3183 free, first `make deploy`, `/up` on loopback (specs/deploy.md setup 4)
- [x] `sites_web_domain_add` (domain 25), vhost and Let's Encrypt certificate provisioned (specs/deploy.md setup 5-6)
- [x] external and local acceptance checks, service and user-manager restart (specs/deploy.md "Verified")
- [ ] full server reboot test in a maintenance window (specs/deploy.md "Verified")
- [ ] operator: sign in, change the admin email and password, delete /root/stopan/admin-password.txt (specs/deploy.md)
- [ ] operator: re-save the remote user in the panel so the function list loses its trailing newline (specs/deploy.md)
- [ ] back up ~stopan/storage (specs/deploy.md)

## Phase 2 - email notifications (2026-10-26, specs/notifications.md)

- [x] notifications spec (specs/notifications.md)
- [x] users.locale and notify_new_tickets; remember the browser language (specs/notifications.md)
- [x] TicketNotifier: batches per transaction, recipients and kinds (specs/notifications.md)
- [x] TicketMailer with five kinds, bg/en, HTML and text, re-checked visibility (specs/notifications.md)
- [x] staff "new tickets" subscription on the account page (specs/notifications.md)
- [x] SMTP from environment variables; file delivery in development (specs/notifications.md)
- [ ] operator: set SMTP_* (and APP_HOST) in the production settings file, then check a reset email (specs/notifications.md, specs/deploy.md)
- [x] durable job queue (Solid Queue 1.7.0) in production, inside Puma as threads: queued emails survive restarts and failed ones are retried 5 times (specs/notifications.md "Delivery")

## Ticket list look (2026-10-26, specs/queues.md, specs/ui.md)

- [x] colour-coded views, list panel and requester tabs; assignee initials badges; set filters highlighted (specs/queues.md)
- [x] ticket search in the menu bar on every page, keeping the list's view and filters (specs/queues.md)
- [x] queue filters apply on change, no Apply button (noscript fallback) (specs/queues.md)
- [x] show the `open` status as "In progress" / "В процес" (specs/tickets.md)
- [x] admin users and organizations lists: filters without the Apply / Search button (specs/admin.md)

## Assignment and sharing (2026-10-26)

- [x] one-click Take and an assign menu in the queue, Take on the ticket page (specs/tickets.md "Assigning", specs/queues.md)
- [x] staff new ticket form lists only the chosen requester's organizations (specs/tickets.md "Creating")
- [x] screenshots: Accept-Language was never sent, so the Bulgarian screenshot was English (specs/ui.md)
- [x] sharing spec (specs/sharing.md)
- [x] share a ticket by link with an optional password; public page with only public content; admin list (specs/sharing.md)
- [x] share link expiry: "Never", 1, 7 or 30 days in the share form and the API; expired links stop at once and the hourly timer clears them (specs/sharing.md "Expiry")
- [x] share links count their views: once per browser within 30 minutes, shown in the Sharing panel, the admin list and the API (specs/sharing.md "Total views")
- [x] admin dashboard shows the running version (`git describe`) and its commit date, written by `bin/deploy` into `REVISION` (specs/admin.md "Version")
- [x] in-app notification panel: bell with unread count, dropdown, notifications page (specs/notifications.md "Notification panel")
- [x] live updates of the notification panel over Action Cable (specs/notifications.md "Live updates of the panel")
- [x] queue views as a horizontal tab row like the admin tabs (specs/queues.md)
- [x] alternate row shading in the queue and My tickets (specs/queues.md "Table")
- [x] shared ticket page refreshes live on public changes (specs/sharing.md "Live updates of the shared page")
- [x] ticket page refreshes live, staff and public streams, waits while the user is busy (specs/timeline.md "Live updates of the ticket page")
- [x] queue and My tickets refresh live (specs/queues.md "Live updates")
- [x] admin pages refresh live (specs/admin.md "Live updates")
- [x] notifications page refreshes live (specs/notifications.md "Live updates of the notifications page")
- [x] preview dialog for images, PDFs and text files (specs/attachments.md "Preview")
- [x] shared page and Sharing panel show how many view the link now (specs/sharing.md "Who is viewing now")
- [x] edit the request and replies, with earlier versions for staff (specs/timeline.md "Editing")
- [x] deploy revision fa69269 to production with a database backup first; migrations ran (specs/deploy.md "Update 2026-10-27")

Organizations: own SMTP, mailbox and public form (operator, 2026-10-27;
decisions: IMAP, address = identity, magic links, form off by default):

- [x] encryption keys from SECRET_KEY_BASE and TRUSTED_PROXIES (specs/organization-mail.md, specs/public-form.md)
- [x] organization mail settings in admin with test buttons; outgoing mail through the organization's SMTP (specs/organization-mail.md)
- [x] magic sign-in links and "email me a sign-in link"; choosing a first password (specs/public-form.md)
- [x] public request page per organization with accounts by email and abuse limits (specs/public-form.md)
- [x] IMAP mailbox per organization: poller, new tickets and replies from mail (specs/organization-mail.md)
- [x] TRUSTED_PROXIES set in production on 2026-11-12 (specs/deploy.md); mail fetching is now a setting
- [x] admins can impersonate a user, with a clear banner and a way back (specs/admin.md "Impersonation")
- [x] flash messages slide in from the right to the centre band and sweep out to the left (specs/ui.md)
- [x] who works on the ticket next to the status in the request note, also for requesters and shared pages (specs/ui.md, specs/sharing.md)
- [x] admin users list: icon actions, quick impersonation, sign-in count (specs/admin.md)
- [x] admins send messages to users, a role, an organization or everyone, shown in notifications (specs/notifications.md "Messages from administrators")
- [x] public page link easy to copy: list icon, organization page, edit form (specs/public-form.md)
- [x] members see their organizations' tickets and get in-app notifications of new ones (specs/roles.md, specs/notifications.md)
- [x] kanban board of tickets by status, like Fizzy (specs/board.md)
- [x] requesters without an organization see nothing but a notice (specs/roles.md)
- [x] "Not now" status (postponed), no email to requesters (specs/board.md "Not now")
- [x] automatic postponing after N days with a setting and a stamp on cards (specs/board.md)
- [x] stages as board sub-columns, managed by admins (specs/board.md "Stages")
- [x] agents see and work only their own organizations; admins everything (specs/roles.md)
- [ ] operator: make production agents members of their organizations before deploying this (specs/roles.md)
- [x] board scrolls better: full window width, columns scroll on their own, edge scrolling while dragging (operator)
- [x] board columns centred when they do not fill the width; a click on an expanded column's header collapses it (specs/board.md)
- [x] one "Done" status instead of resolved and closed, everywhere; replies reopen it, no final close (specs/tickets.md "One Done status")
- [x] board has the list's filters: status, priority, assignee, organization, sort; one shared partial (specs/board.md)
- [x] production: deployed 3e50793 with `MergeResolvedAndClosedIntoDone`, after a database backup (specs/deploy.md)
- [x] organization list of email addresses or domains allowed to use the public request page (operator)
- [x] README screenshots refreshed, with a fifth one of the board (specs/ui.md "Screenshots")
- [x] menu bar marks "Queue" on the board too (specs/ui.md "Menu bar")
- [x] one line per ticket row: requester in its own column, subject ends in an ellipsis from 1024px (specs/queues.md "Table")
- [x] language switch in the header (BG/EN) and a Language choice on the account page, kept per user and used for emails (specs/ui.md "Language")
- [x] menu bar wraps under 960px with the search on its own row, so it never runs off the screen (specs/ui.md "Menu bar")
- [x] board moves and task boxes send POST with `_method` (the server WAF refuses PATCH) (specs/deploy.md "ModSecurity false positives")
- [x] production: ModSecurity exclusions for Cyrillic text (941310) and Accept-Charset, `ProxyPass /error/ !` (specs/deploy.md "ModSecurity false positives")
- [x] production: random 403 on HTML pages: CRS 953120 matched `<?` in the zstd/gzip body Thruster compressed; `SecDisableBackendCompression On` in the site directives, Apache mod_deflate compresses after ModSecurity (specs/deploy.md "ModSecurity and compressed pages")
- [x] `public/apple-touch-icon-precomposed.png`, a copy of the touch icon (iOS and macOS asked for it, 404) (specs/ui.md)
- [x] host firewall: FireHOL allowed outgoing 993 (IMAPS) only for one admin user, so the container (pasta, user `stopan`) could not fetch mail; `stopan` added to the imaps client rule (specs/deploy.md "Outbound IMAP blocked by the host firewall")
- [x] production: deployed cbf319b with `AddLanguageToUsers`, after a database backup (specs/deploy.md)
- [x] German UI (`de`): app, Devise and Rails texts, header switch with one button per other language, German page and email tests (specs/ui.md "Translations", "Language")
- [x] menu bar shows the role as an icon (person, headset, shield) with its name as tooltip and label (specs/ui.md "Menu bar")
- [x] production: deployed 8f4eb97 (German, role icon), after a database backup (specs/deploy.md)
- [x] header language switch only when signed out and on shared pages; signed-in users choose on the account page (specs/ui.md "Language")
- [x] production: deployed 0f52988 (language buttons only for visitors and shared pages), after a database backup
- [x] language buttons as one group like the text sizes: "EN BG DE", current shaded (specs/ui.md "Language")
- [x] "Translate" button on messages for staff with DeepL, admin switch, stored translations (specs/translation.md)
- [x] DeepL key entered on /admin/settings, stored encrypted and write-only; DEEPL_API_KEY only a fallback (specs/translation.md)
- [x] production: deployed ff0f444 (translation, key in settings, language group), after a database backup (specs/deploy.md)
- [ ] operator: after the next deploy, enter the DeepL key and switch translation on in /admin/settings, after checking DeepL's data terms (specs/translation.md)
- [x] statistical reports page for staff: tiles, created/done chart, open by status, by organization, by person (specs/reports.md)
- [x] burndown chart on the reports page, replayed from status events (specs/reports.md "Burndown")
- [x] separate "Board" pill in the menu bar; the bar wraps under 1180px, the search shrinks first, pills wrap on phones (specs/ui.md "Menu bar")
- [x] production: deployed d757d14 (reports with burndown, Board pill), after a database backup (specs/deploy.md)
- [~] Google Workspace mail accounts, phase 1: XOAUTH2 in the libraries confirmed locally; live check waits for an Internal OAuth client and a test mailbox (specs/mail-oauth.md)
- [x] Google Workspace mail accounts, phase 2: OAuth client settings, connect / callback / disconnect, mail_connections (specs/mail-oauth.md "As built")
- [x] Google Workspace mail accounts, phase 3: token refresh, XOAUTH2 in MailboxCheck and SMTP, failure handling (specs/mail-oauth.md "As built")
- [x] production: deployed 8961aaa (Google accounts for organization mail), after a database backup (specs/deploy.md)
- [x] phone menu bar in three rows: icon and tools, section pills on their own row, search (specs/ui.md "Menu bar")
- [x] themes: notes (Stickies) and omarchy (omamobile.org look, Tokyo Night / Catppuccin Latte), chosen on the account page (specs/ui.md "Themes")
- [x] themes later: bundle JetBrains Mono and Geist (OFL) so omarchy does not depend on the system's fonts (specs/ui.md "Themes")
- [x] site-wide default theme in /admin/settings; users may still pick their own (operator, 2026-10-27; specs/ui.md "Themes")
- [x] Google mail setup as a step-by-step wizard instead of manual settings (operator, 2026-10-27; specs/mail-oauth.md "Setup wizard")
- [x] wizard path for Gmail with an app password, no Google Cloud (operator, 2026-10-27; specs/mail-oauth.md "App password path")
- [x] automatic mail fetching on /admin/settings: on/off and every 1-15 minutes, applies without restart; on in dev (operator, 2026-10-27; specs/organization-mail.md "Fetching")
- [ ] production: turn on "Fetch new mail automatically" in /admin/settings after the next deploy
- [x] mail-shaped display for messages with source email (rules, quotes, softer footer and signature) and short links for addresses in all plain text (operator, 2026-10-27; specs/organization-mail.md "Display of mail", specs/markdown.md "Plain text links")
- [x] mail details for staff at the start of a mail ticket, Roundcube-style header (operator, 2026-10-27; specs/organization-mail.md "Mail details")
- [x] mail HTML view like Roundcube: cleaned HTML part in a sealed frame (own CSP, sandbox), remote images blocked until "Show images", HTML/Text tabs (operator, 2026-10-27; specs/organization-mail.md "HTML view")
- [x] mail HTML: replies by mail keep and show their HTML, and inline `cid:` images show from the message's own files (specs/organization-mail.md "Replies and inline images")
- [x] JSON API /api/v1 with personal tokens (read-only option, expiry, revoke), same rights as the pages, admin endpoints (operator, 2026-10-27; specs/api.md)
- [x] API: OpenAPI 3.1 description at `GET /api/v1/openapi.json`, kept complete by a test against the routes; `PATCH /api/v1/memberships/:id` got its missing action (specs/api.md "OpenAPI")
- [x] webhooks per organization for new tickets and public replies: signed, https on public addresses only, retried, managed by super administrators on the organization page and in the API (specs/webhooks.md)
- [x] bulk actions in the queue and search: check boxes, status/priority/assignee for the selection or the whole list (max 500), skipped tickets named; also PATCH /api/v1/tickets/bulk (operator, 2026-10-27; specs/queues.md "Bulk actions")
- [x] own account page laid out as panels across the screen like the admin pages (operator, 2026-10-27; specs/ui.md "Own account page")
- [x] the request's copy box copies the ticket's facts (status, priority, assignee, requester, organization, created, link, mail headers for staff) before the text (operator, 2026-10-27; specs/ui.md "Copy box")
- [x] hiding a translation folds it back to the Translate button, which shows it again without DeepL (operator, 2026-10-27; specs/translation.md)
- [x] soft delete of tickets by staff (page, bulk, API); admins review and restore them under Admin > Deleted tickets (operator, 2026-10-27; specs/tickets.md "Deleting")
- [x] person profile with statistics for staff, opened from "Requester" on the ticket page; queue filter by requester (operator, 2026-10-27; specs/people.md)
- [x] advanced search in the queue: all words, also in replies, requester, created and activity dates, source, attachments (operator, 2026-10-27; specs/queues.md "Advanced search")
- [x] organization page: member picker with live search and check boxes, several at once (operator, 2026-10-27; specs/admin.md "Adding members")
- [x] production: deployed 59175fa (everything since 8730df2, 8 migrations) after a database backup (specs/deploy.md)
- [ ] operator: try the API through Apache with a personal token (PATCH/DELETE and JSON bodies vs ModSecurity)
- [x] production: mail fetching switched on in /admin/settings (every 2 minutes); the first check after the firewall change fetched mail (specs/organization-mail.md "Fetching")
- [x] README screenshots refreshed, all in English (Chrome with an English environment); the phone shot is now ticket-requester-phone.png (operator, 2026-10-27; specs/ui.md "Screenshots")
- [x] README: Mermaid diagram of how tickets come in (ingress workflow) (operator, 2026-10-27; specs/overview.md "Ingress diagram")
- [x] README ingress diagram made simple: six boxes left to right, details in a list (operator, 2026-10-27)
- [x] README shows only the queue screenshot; the other four removed from the README, bin/screenshots and docs/screenshots (operator, 2026-10-28; specs/ui.md "Screenshots")
- [x] account page and admin settings: panels in fixed flex columns instead of CSS columns, which Safari split under the big/extra text size; settings fit 1440x900 without scrolling; stage rows wrap inside their panel (operator, 2026-10-28; specs/ui.md "Panel columns")
- [x] production: deployed bf47c22 (panel columns, site icon, README) after a database backup (specs/deploy.md)
- [x] menu bar wraps at the big and extra text sizes (breakpoint times the zoom); window units and script positions undo the zoom, so the board and dialogs fit the window; no sideways scroll at any size from 1024px (operator, 2026-10-28; specs/ui.md "Text size zoom")
- [x] advanced search only in the queue, not on the board (operator, 2026-10-28; specs/queues.md "Advanced search")
- [x] production: deployed 242b476 (text size zoom, menu bar, board without advanced search) after a database backup (specs/deploy.md)
- [x] Search page: own menu bar section for staff with the text field, filters and advanced search (moved from the queue), results with bulk actions (operator, 2026-10-28; specs/queues.md "Search page")
- [x] production: deployed 9c67bf4 (Search page) after a database backup (specs/deploy.md)
- [x] production: deployed 50475d3 (documentation only) after a database backup (specs/deploy.md)
- [x] admin: flush all tickets of an organization after typing its name, keeping its settings; numbers never reused (operator, 2026-10-27; specs/admin.md "Flush all tickets of an organization")
- [x] requester email on the ticket page and the profile copies on click instead of opening the mail program (operator, 2026-10-27; specs/ui.md "Emails copy on click")
- [x] mail replies: keep their headers too, shown to staff under "Mail details" and in the API (specs/organization-mail.md "Mail details")
- [x] requesters see only their own tickets; "My organizations" tab, organization list stream and colleague notice removed (operator, 2026-10-27; specs/roles.md)
- [x] long original request collapses with "Show the whole request" (operator, 2026-10-27; specs/timeline.md "Long requests collapse")
- [x] timeline order: oldest or newest first, site default in /admin/settings and per browser on the account page; newest first puts the composer on top (operator, 2026-10-27; specs/timeline.md "Order of the timeline")
- [x] mobile rules from Apple / Material / WCAG: 44px targets, 16px fields, no sideways scrolling, no hover-only content (specs/mobile.md)
- [x] production: deployed 8730df2 (omarchy theme, phone menu bar), after a database backup
- [x] admin dashboard warning for organizations whose Google account needs reconnecting, live (specs/admin.md "Google accounts that need reconnecting", specs/mail-oauth.md "Failure")
- [ ] Google Workspace mail accounts, phase 4: production OAuth client and first mailbox (specs/mail-oauth.md, specs/deploy.md)
- [ ] Microsoft 365 mail accounts, the same phases, after Google (specs/mail-oauth.md)
- [x] reports: CSV export of each table, with a guard against spreadsheet formulas (specs/reports.md "CSV export")
- [x] production: deployed 0ae905e (CSV export of the reports), no migrations (specs/deploy.md "Update 2026-11-12 (revision 0ae905e)")
- [x] reports: custom date range (`period=custom` with `from` and `to`), on the page, in the CSV and in the API (specs/reports.md "Custom range")
- [ ] reports later: business hours (specs/reports.md "Later")

Plan: g0no's note display options for tickets (proposed 2026-10-27,
approved "go in this order", all done 2026-10-27):

- [x] copy box on every message (request, reply, note, shared page) puts its text on the clipboard (g0no ui.md "Copy box")
- [x] Markdown per message: a box in the title strip and a composer check box, GFM via commonmarker with sanitize (g0no markdown.md); emails get formatted HTML, the text part stays plain
- [x] double-click on text you may edit opens the in-place edit form with the caret near the click; Escape cancels (g0no "Locked notes")
- [x] earlier versions with word-by-word changes (green / red) and "Restore this version" for staff (g0no history.md, TextDiff)
- [x] wide ticket view, a per-user preference like theme and text size (g0no "Wide notes")
- [x] clickable Markdown task lists for users who may edit; clicks by one person within 10 minutes form one revision (g0no markdown.md "Task lists")
- [x] shared page one column that follows the width switch; width box on the original request; g0no-style in-place editing (specs/ui.md, specs/timeline.md)
- [x] ticket header inside the request note: bold number before the subject, no breadcrumb (specs/ui.md "Ticket page")
- [x] add `upgrade=websocket` to the production Apache ProxyPass through the ISPConfig API; /cable upgrades with 101 (specs/deploy.md "WebSocket proxy")

## Logo (2026-10-27, specs/ui.md "Logo")

- [x] redraw the mark from stopan.png as SVG and draw seven candidates in the app's style (docs/logos/)
- [x] operator: pick a candidate (or a mix: tab icon, menu bar, Omarchy) - chose 3, sticky icon
- [x] use the chosen logo: public/icon.svg, icon.png, apple-touch-icon.png, favicon.ico (the menu bar already shows icon.svg)
- [x] candidate 1 in black instead of teal (operator)
- [ ] decide: own icon for the Omarchy theme (candidate 6) and a logo header in emails (specs/ui.md "Logo")
- [x] app icon back to the check-mark sticky (better at 16 and 18 px); candidate 3 heads the README only (specs/ui.md "Logo")
- [x] deploy the restored app icon to production (specs/deploy.md "Update 2026-10-28 (revision 8e1fe51)")

## Organization page (2026-10-28, specs/ui.md "Admin")

- [x] details panel: public form address no longer shrinks to "https:"; space above section titles
- [x] deployed 7767fc0 to production (specs/deploy.md "Update 2026-10-28 (revision 7767fc0)")

## Requester emails for tickets from email (2026-10-28, specs/sharing.md "Link in the requester's emails")

- [x] the requester's notification emails of a ticket from email link to the shared page; a link with the recipient's address as password is made when none exists
- [x] the share password form accepts an address in any case or with spaces around it
- [x] with the organization's mailbox on, the footer and the pending/done hints say to answer by replying to the email; staff are told a reply becomes a public reply (specs/notifications.md "Where to answer")

## Shared mailbox between environments (2026-10-28)

- [x] customer replies on #1009 missing: a development copy polled the same Gmail account and folder, marked the replies \Seen and made its own tickets of them; the replies were marked unseen and fetched by production (session note)
- [x] take only messages addressed to the organization's `mailbox_address` (IMAP `UNSEEN` with the address in To, Cc or Delivered-To), so two installations with different +addresses on one account do not take each other's mail (specs/organization-mail.md "Fetching")

## Email language per organization (2026-10-28, specs/organization-mail.md "Settings")

- [x] `organizations.mail_locale` (migration `AddMailLocaleToOrganizations`) and the "Language of emails to requesters" select in the Mail panel
- [x] `User#mail_locale`: the recipient's own choice, then for requesters the organization's language, then the browser's, then English; used by TicketMailer, PublicRequestMailer and AccountMailer (specs/notifications.md "Language")
- [x] deployed fab4c24 with a database copy first (specs/deploy.md)

## Quote levels in mail (2026-10-28, specs/organization-mail.md "Display of mail")

- [x] `>` quotes nest by level with a colour per level; earlier messages quoted without `>` (Outlook header blocks, forward separators) become collapsible sections, closed below the message's own text
- [x] the copy box copies closed sections too, without their summary lines
- [x] the HTML view of the mail of a deleted ticket fails for administrators; its files and previews did too. They now load the ticket like the page (`find_ticket_for_page`) (specs/tickets.md "Deleting")
- [x] replies from Outlook kept the quoted earlier message in the stored text; replies are now cut at the header block the ticket page shows as an earlier message (`MailQuote`), a forward inside a reply stays (specs/organization-mail.md "Processing a message")

## Side column fixes (2026-10-28)

- [x] the requester's email stays on one line (ellipsis when too long, whole address in the tooltip and the copy); a stale `.copy-value` block rule from the Google page made it a wrapping box (specs/ui.md "Emails copy on click")
- [x] the share link field takes its own row in the side column, the copy button under it (specs/sharing.md "Managing the link")

## Ticket page on phones (2026-10-28, specs/ui.md "Ticket page on phones")

- [x] menu button on phones: sections, preferences and account behind it; no search on a ticket page (specs/ui.md "Menu bar")
- [x] Properties, Requester and Sharing start closed on phones and open from their title strip
- [x] the side panels one per row on phones (two columns from about 500px before)
- [x] Properties panel on blue paper instead of grey, which was close to the desk colour (specs/ui.md "Ticket page")
- [x] composer behind a sticky Reply bar on phones; close box keeps the text
- [x] notification panel above the page on phones (menu bar `position: relative`)
- [x] production: deployed 0d9f426 after a database backup (specs/deploy.md)
- [x] production: removed the seven older database copies of 2026-10-28; kept `pre-deploy-bf4036c` (the last one) and the copies of 2026-10-27

## Who is online now (2026-10-28, specs/presence.md)

- [x] live refresh of lists and tickets on new tickets and mail checked again in development (a ticket made in another session appears in an open queue within 3 seconds); nothing to change
- [x] presence: `Presence` (process memory), `PresenceChannel` on every signed-in page, signal `presence_refresh` to staff, `GET /presence` as Turbo Stream
- [x] menu bar button for staff: dot, staff avatars, number online; panel with staff names and the requester count
- [x] ticket page: "Also viewing now" with the others who have the ticket open

## Alignment and menus (2026-10-28, specs/ui.md)

- [x] bulk bar: "Delete" on the line of the other buttons (the quiet destructive button's top margin is for the properties panel only)
- [x] admin settings: Stages as a full-width panel under the columns, one stage per row, new stage form on one row
- [x] menu bar: the name and Logout in an account menu (dropdown with "Your account" and "Logout")
- [x] production: removed the backups `pre-deploy-bf4036c` and `pre-deploy-0d9f426`; `pre-deploy-989950a` stays as the rollback copy
- [x] account menu: role icon before the name; optional nickname (`users.nickname`, account page and admin form) shown there instead of the name (specs/data-model.md, specs/ui.md "Menu bar")
- [x] queue and board: no visible page title (sr-only h1); reports: period and organization selects on the title's row (specs/ui.md "Pages", specs/reports.md "Filters")
- [x] menu bar: "New ticket" as a green "+" after the name instead of a section pill (specs/ui.md "Menu bar")
- [x] no "New ticket" buttons on the queue, the board and My tickets; the menu bar "+" replaces them
- [x] production: removed the backup `pre-deploy-989950a`; `pre-deploy-dfb32f4` stays as the rollback copy
- [x] "Admin" moved from the section pills into the account menu, for administrators only (specs/ui.md "Menu bar")
- [x] queue: the view tabs on the header row with the List | Board switch, which keeps one place on the list and the board (also on phones)
- [x] board: the filters on one row with the List | Board switch and "New ticket" (specs/board.md)
- [x] search page: one visible title, the pink panel's strip; the `h1` is for screen readers only (specs/queues.md "Search page")
- [x] organization details panel reworked: count tiles, mail as two cards with on/off pills and their own actions, message to members under the members list (specs/ui.md "Admin")

## Super and organization administrators (2026-10-29, specs/org-admins.md)

- [x] `memberships.admin` mark for agents, cleared when the role changes; `administered_organizations`, `administers?`, `org_admin?`, `admin_area?`
- [x] `AdminScope`: organizations, users, manageable and addable users, removable memberships, deleted tickets; every admin controller finds records through it
- [x] super administrator only: overview, settings, stages, Google wizard, impersonation, creating and deleting organizations, setting the mark
- [x] organization pages, members, users, messages, danger zone, deleted tickets and mail sign-in limited to administered organizations
- [x] "Administrator" shown as "Super administrator"; shield toggle for the mark on member rows; organization admin pill
- [x] production: deployed 5fd80c0 (migration `AddAdminToMemberships`; backup `pre-deploy-3f367da`) (specs/deploy.md)
- [x] production: removed the backup `pre-deploy-dfb32f4`; `pre-deploy-3f367da` stays as the rollback copy
- [x] production: two former super administrators are now agents who administer their organization; one super administrator remains

## Attachments: request size limit (2026-10-31, specs/attachments.md "Request size")

- [x] gap analysis of attachments against the specs (session/2026-10-31-attachments.md)
- [x] refuse request bodies over `MAX_REQUEST_BODY` (default 52 MiB) in Puma and Thruster, before the body is stored (specs/attachments.md "Request size", specs/docker.md)
- [x] tests: the limit stays above the attachment limits; reply files and refused types through the API (specs/attachments.md "Acceptance")
- [x] commit the change on branch `attachments-request-limit` (0bc597e)
- [x] merge `attachments-request-limit` into main (fast-forward to 0bc597e)
- [x] production: ModSecurity allowed only 12.5 MiB; `SecRequestBodyLimit 54525952` set in the Stopan site's directives; 20 MiB now reaches the app, 53 MiB gets 413 (specs/deploy.md "Request size")
- [x] production: deployed 28361df (no migrations; backup `pre-deploy-5fd80c0`) (specs/deploy.md "Update 2026-11-01")
- [ ] production: upload 5 files near 10 MB as a signed-in user on a test ticket, then delete the ticket

## Super administrators see their own organizations' tickets (2026-11-02, specs/roles.md)

- [x] `Ticket.visible_to` and `visible_organizations` by membership for super administrators too; the admin area still covers every organization
- [x] assignment only to the organization's staff; new tickets only in own organizations; presence counts, the overview's shared list and deleted tickets (pages and API) by membership
- [x] production: deployed with 1fa5564; a super administrator who works an organization's tickets adds themselves as a member

## Emails to the requester: switch and record (2026-11-02, specs/notifications.md "Emails to the requester")

- [x] `tickets.email_requester` (default on); "Email the requester" toggle in the composer for public replies, saved at once, with the warning that mail leaves Stopan
- [x] internal timeline events `mail_switched`, `mail_sent`, `mail_skipped` (switched off, no SMTP) and `mail_failed`, for emails to the requester only
- [x] production: deployed 1fa5564 (migration `AddEmailRequesterToTickets`; backup `pre-deploy-28361df`) (specs/deploy.md)

## Followers and Cc (2026-11-02, specs/followers.md)

- [x] `ticket_followers`; staff followers (follow, add a colleague, automatic on writing) and customer Cc (by email, from the mail's To/Cc as suggestions)
- [x] Cc in `Ticket.visible_to` (public part only), My tickets with a "Cc" tag, public replies in Stopan and by email
- [x] notifier: followers and Cc as recipients; the email switch covers Cc; mail events carry the address (`ticket_events.detail`)
- [x] People panel on the ticket page; internal follower events
- [x] production: deployed 018a5a2 (migrations `CreateTicketFollowers`, `AddDetailToTicketEvents`; backup `pre-deploy-1fa5564`) (specs/deploy.md)
- [x] people in Cc get the shared page in their emails (on every ticket), opened with their own address on the automatic link
- [x] production: removed the 14 older backups; `pre-deploy-1fa5564` stays as the rollback copy
- [x] shared page password form: eye button to show and hide what was typed (specs/sharing.md "Show what was typed")
- [x] the password eye also on sign-in, password reset and the own account page (specs/ui.md "Password fields")
- [x] the password eye as a separate button beside the field, so password manager icons inside the field stay free
- [x] image preview sized to the image up to the window, with actual size for scaled images (specs/attachments.md "Image size")
- [x] production: deployed db88326 (image preview sizes), no migrations (specs/deploy.md)
- [x] runs of 3 or more event lines between messages fold into one line (specs/timeline.md "Event lines between messages fold")
- [x] OpenSSF Scorecard workflow with pinned actions, and the Scorecard badges in the README (specs/ci.md)
- [x] production: deployed 4c73f97 (folded event runs), no migrations (specs/deploy.md)
- [x] Scorecard: first run on `main` passed, both badges show; first score 3.8 (specs/ci.md "Acceptance")
- [x] SECURITY.md with private vulnerability reporting (specs/ci.md "Security policy")
- [x] base images and the BuildKit frontend pinned by digest in Dockerfile and Dockerfile.dev (specs/docker.md "Pinned base images")
- [x] private vulnerability reporting turned on in the GitHub repository settings (specs/ci.md "Security policy")
- [x] LICENSE: BSD 2-Clause (specs/overview.md "License")
- [x] production: deployed 436dd64 (pinned base image), no migrations (specs/deploy.md)
- [x] Dependabot version updates for GitHub Actions and gems, grouped, with a cooldown (specs/ci.md "Dependency updates")
- [x] Dependabot alerts turned on in the repository settings (specs/ci.md "Dependency updates")
- [x] Dependabot security updates (automatic fix pull requests) turned on in the repository settings (specs/ci.md "Dependency updates")
- [x] gem security fixes from `make audit`: sqlite3 2.10.2, crass 1.0.8, loofah 2.25.3, nokogiri 1.19.7, rack 3.2.8, rails-html-sanitizer 1.7.2, with bootsnap 1.26.1 and msgpack 1.8.7 (specs/ci.md "Dependency updates")
- [x] production: deployed 6a89f1d (gem security fixes), no migrations (specs/deploy.md)
- [x] `make check` runs `make audit`: advisory database updated first, local copy when offline; ignore entries need a reason and a date (specs/ci.md "Gem audit in make check")
- [x] releases: SemVer from 0.x, `make release VERSION=x.y.z` (checks, tag, GitHub release), `bin/release-notes` from Conventional Commits; SECURITY.md supports the latest release (specs/release.md)
- [x] first release v0.1.0: tag on 0f74129, GitHub release marked latest (specs/release.md)
- [x] production: deployed v0.1.0 (0f74129) from its tag, no migrations (specs/deploy.md)
- [x] signed release tags with a separate SSH ed25519 key: bin/release signs, verifies against .github/allowed_signers, then pushes (specs/release.md "Signed tags")
- [x] the signing key is a signing key on the GitHub account; signed tags show "Verified" (specs/release.md "Signed tags")
- [x] Rails 8.1.4.1 security release, found by the audit in make check (specs/ci.md "Gem audit in make check")
- [x] release v0.1.1, the first signed tag (Rails 8.1.4.1 and signed tags), GitHub shows it "Verified" (specs/release.md)
- [x] production: deployed v0.1.1 (3a4f4c5) from its tag, Rails 8.1.4.1, no migrations (specs/deploy.md)
- [x] signed release files: source archive and SSH signature on every release, `make release-files` for earlier releases; attached to v0.1.0 and v0.1.1; Scorecard Signed-Releases 8 (specs/release.md "Signed release files")
- [x] SLSA build provenance: release build on GitHub Actions (`.github/workflows/release.yml`, `actions/attest-build-provenance`); `bin/release` checks the run, the provenance and the archive, then signs and publishes (specs/release.md "Release build")
- [x] SLSA provenance on v0.1.0 and v0.1.1 with `make release-files`; Scorecard Signed-Releases 10, total 6.3 (specs/release.md "Signed release files")
- [x] SLSA Build Level 3: build and attestation in the reusable workflow `.github/workflows/release-build.yml`, the build job without the OIDC token, a separate provenance job; `--signer-workflow` names it (specs/release.md "Release build")
- [x] Level 3 provenance on v0.1.0 and v0.1.1 with `make release-files`; archives and signatures unchanged, Scorecard Signed-Releases 10, total 6.3 (specs/release.md "Signed release files")
- [x] verify commands in the release notes of v0.1.0 and v0.1.1 (specs/release.md "Signed release files")
- [x] Heroicons 2.2.0 replace the own icons, and icons on buttons, flash messages, panels, menu sections, account menu and timeline lines (specs/ui.md "Icons")
- [x] form fields: one base style, selects with a chevron, check boxes and radios, errors under the field (FieldFormBuilder), file drop zone, leading icons, joined input and button groups (specs/ui.md "Form fields")
- [x] form fields, open: the drop zone leaves out files past the 5-file / 10 MB limits before sending; the Google setup copy fields, a new API token and the public link joined to their buttons; FieldFormBuilder in app/form_builders, dev container restarted (specs/ui.md "Form fields")
- [x] production: deployed fd2638b (icons and form fields), no migrations (specs/deploy.md)
- [x] composer: the status select above the send button, one column as wide as the wider of the two; full width on phones (specs/timeline.md "Composer")
- [x] searchable selects (combobox over the real select) for the new ticket requester and the queue assignee and organization filters (specs/ui.md "Searchable selects")
- [x] copy button on Markdown code blocks (specs/markdown.md "Copy code")
- [x] STOPAN wordmark (traced, currentColor SVG) in place of the name in the menu bar (specs/ui.md "Logo")
- [x] every button as high as the fields, except .btn--small (specs/ui.md "Form fields")
- [x] production: deployed fa54a8b (composer layout, searchable selects, code copy, wordmark, button heights), no migrations (specs/deploy.md)
- [x] /tickets/new busy for the live refresh: idle on a plain load; after a failed submit the script's pick of the requester's only organization counted as a change, now it becomes the starting value (specs/tickets.md "Creating")
- [x] a person in Cc leaves: "Leave Cc" on the People panel, and a link at the end of every follower's and Cc's email to a confirmation page without sign-in (specs/followers.md "Leaving")
- [x] followers in the API: `followers` and `cc_suggestions` in the ticket, `POST` and `DELETE /api/v1/tickets/:number/followers` (specs/followers.md "In the API", specs/api.md)
- [x] production: deployed 87769cd (leaving a ticket, followers in the API), no migrations (specs/deploy.md "Update 2026-11-12 (revision 87769cd)")
- [x] production: deployed 34f3e79 (automatic done, off by default), one additive migration, database copied first (specs/deploy.md "Update 2026-11-12 (revision 34f3e79)")
- [x] the requester adds colleagues to Cc on their own ticket, only among members of the ticket's organization, and removes the ones they added; in the API too (specs/followers.md "The requester adds colleagues")
- [x] production: deployed c802739 (the requester adds colleagues to Cc), no migrations (specs/deploy.md "Update 2026-11-12 (revision c802739)")
- [x] production: deployed 10b393b (durable job queue), database copied first, the queue checked on the server (specs/deploy.md "Update 2026-11-12 (revision 10b393b)")
- [x] production: deployed ec72cc5 (sign-in and password reset rate limits) and set `TRUSTED_PROXIES`; the limit checked to be per visitor (specs/deploy.md "Update 2026-11-12 (revision ec72cc5)")
- [x] production: deployed d0db217 (share link expiry, version on the admin dashboard), database copied first (specs/deploy.md "Update 2026-11-12 (revision d0db217)")
- [x] production: deployed 97c3f7d (custom range in the reports, view count of share links), database copied first (specs/deploy.md "Update 2026-11-12 (revision 97c3f7d)")
- [x] production: deployed d9d7207 (OpenAPI description, webhooks, HTML of mail replies and inline images), database copied first (specs/deploy.md "Update 2026-11-12 (revision d9d7207)")
- [ ] production: once an organization exists, add a webhook to a real receiver and check a delivery and its signature (specs/webhooks.md)
- [x] decided: people outside the organization never go in Cc; the share link remains for them (specs/followers.md "Not in this phase")
- [x] production: database reset, the old database and uploads kept in `~stopan/backups/reset-2026-11-09` (specs/deploy.md "Database reset (2026-11-09)")
- [ ] operator: after the reset, sign in as `admin`, change its email and password, then add the organizations, people and settings again (specs/deploy.md "Database reset (2026-11-09)")
- [x] production: deployed 98a5e93 (`main` after v0.1.1: file limits, joined copy fields, deleted ticket mail and files, mailbox address filter, Outlook replies), no migrations (specs/deploy.md "Update 2026-11-10 (revision 98a5e93)")
- [x] production: deployed b482106 (dashboard warning for Google accounts to reconnect, headers of mail replies, bundled Omarchy fonts), one additive migration, database copied first (specs/deploy.md "Update 2026-11-11 (revision b482106)")
- [ ] once a mailbox is set up again in production, check that "Check the mailbox" and the run take only mail for its address (specs/organization-mail.md "Fetching")

## Later (specs/roadmap.md)

- [x] rate limit sign-in (20 per 5 minutes per address) and password reset requests (5 per 10 minutes per address and per email) (specs/auth.md "Rate limits")
- [x] `TRUSTED_PROXIES` set in production, so the sign-in limit is per visitor (specs/deploy.md "Update 2026-11-12 (revision ec72cc5)")
- [ ] email ingestion with Action Mailbox (specs/roadmap.md)
- [x] automatic done: pending tickets without activity for N days are marked done, off by default (`app_settings.auto_done_days`; specs/board.md "Automatic done")
- [x] SLA targets per priority: first response and resolution, set in /admin/settings, shown to staff on the ticket page and as a mark in the queue, in the API (specs/sla.md)
- [ ] SLA later: business hours, stopping the clock while pending, breach notifications, an overdue filter, numbers in the reports (specs/sla.md "Not in this version")
- [ ] live ticket and queue updates over Turbo Streams (specs/roadmap.md)
- [ ] agent groups and organization-wide requester visibility (specs/roadmap.md)
- [ ] reporting (specs/roadmap.md)
- [x] JSON API (specs/roadmap.md; built 2026-10-27, specs/api.md)
- [ ] headless browser system tests (specs/roadmap.md)
- [x] admin users list: hide Delete for users with ticket history instead of refusing on submit (specs/admin.md)
- [x] build and check the Stopan Docker image, `make docker-check` (specs/docker.md)
- [x] development in Docker with live code reload, `make docker-dev` (specs/docker.md)
- [x] demo organizations and users seeded in the development container (specs/auth.md, specs/docker.md)
- [x] add gitleaks as a pre-commit hook, `make hooks`, scan in `make lint` (specs/overview.md)
- [ ] regenerate the local .env copied from g0no (specs/auth.md)

## Archive - g0no baseline

The list below is g0no's record, copied with the code on 2026-10-25. It
describes the notes app Stopan started from; open items in it do not apply
to Stopan unless they are listed above.

- [x] upgrade from Rails 3.0.5 to Rails 8.1.4 on Ruby 4.0 (specs/overview.md)
- [x] replace CouchDB with SQLite and Active Storage (specs/data-model.md)
- [x] import task for the 2011 CouchDB data (specs/couchdb-import.md)
- [x] Devise 5 with support for 2011 password hashes (specs/auth.md)
- [x] replace jQuery/Prototype with plain JavaScript; compile Sass to CSS (specs/overview.md)
- [x] Docker image and compose file (specs/docker.md)
- [x] Makefile, specs, todo and session notes per ../AGENTS.md
- [x] make run creates .env with a random admin password and the admin user if missing (specs/auth.md)
- [x] macOS Stickies style UI, translated account pages (specs/ui.md)
- [x] admin panel for administrators: users, stats, shared notes (specs/admin.md)
- [x] attachment count on note cards (specs/features.md)
- [x] preview dialog for attachments (specs/features.md)
- [x] share a note by link, optionally with a password (specs/sharing.md)
- [x] menu bar search with colour filter (specs/features.md)
- [x] change a note's colour from the fixed Stickies set (specs/features.md)
- [x] informative confirm dialog instead of "Are you sure?" (specs/features.md)
- [x] drag and drop upload onto a note (specs/features.md)
- [x] note history with Time Machine style view and restore (specs/history.md)
- [x] random colour button next to the colour set (specs/features.md)
- [x] autosave notes, no Save / Cancel (specs/features.md)
- [x] light / dark theme switch and three text sizes (specs/features.md)
- [x] description grows without a scroll bar; copy box for the note's text (specs/ui.md)
- [x] yellow sticky site icon (specs/ui.md)
- [x] notes locked on single click, unlocked by double-click (specs/features.md)
- [x] Markdown switch per note with clickable task lists (specs/markdown.md)
- [x] double-click puts the caret where clicked, also in Markdown notes (specs/markdown.md)
- [x] text size as three A buttons; no scroll bar at Big / Extra big (specs/features.md)
- [x] sort button on the board with light rearrange animation (specs/features.md)
- [x] search and colour filter moved from the menu bar to the board header (specs/features.md)
- [x] Turbo Drive (specs/ui.md)
- [x] menu bar brand and section pills in the app style (specs/ui.md)
- [x] keep the page still when a long note is unlocked (specs/features.md)
- [x] per-note wide option (specs/features.md)
- [x] live updates of note and share pages over Action Cable (specs/live-updates.md)
- [x] deploy live updates to production (specs/deploy.md)
- [x] add `upgrade=websocket` to the installed Apache vhost, for live updates (specs/deploy.md)
- [x] close sign-up in production with REGISTRATION_OPEN (specs/auth.md)
- [x] deploy to the server: rootless Podman as g0no, Apache, certbot (specs/deploy.md)
- [x] disable PageSpeed for the production vhost after its global CSS rewrite
      returned zstd bytes without `Content-Encoding` (specs/deploy.md)
- [ ] check the app comes back after a server reboot (specs/deploy.md)
- [ ] check file uploads through Apache and mod_security in production (specs/deploy.md)
- [ ] back up ~g0no/storage on the server (specs/deploy.md)
- [x] fix 404 on stopan.linuxfan.org: ModSecurity CRS 941120 false positive on the session cookie, excluded per site (specs/deploy.md)
- [ ] configure SMTP from environment variables so password reset emails work (specs/auth.md)
- [ ] expose the tag field in the note form (it was commented out in 2011) (specs/features.md)
- [ ] add gitleaks as a pre-commit hook (../AGENTS.md)
- [ ] share-password rate limit is per process; move to a shared store if the app runs several processes (specs/sharing.md)
- [ ] delete a single history version (for text pasted by mistake) (specs/history.md)
- [ ] previews and downloads load the whole file into memory; stream large files (specs/features.md)
