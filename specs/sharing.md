# Sharing a ticket by link

Requested by the operator on 2026-10-26: "tickets can be shared, like in
g0no". Modelled on g0no's note sharing (a secret link, optionally with a
password), with one extra rule for a service desk: a shared page shows only
what the ticket's requester sees, never internal content.

## Who may share

| action | requester | agent | admin |
|--------|-----------|-------|-------|
| create, replace or stop the link of a ticket | own ticket, in own organization (`TicketPolicy#own?`) | any ticket | any ticket |
| see all shared tickets and stop sharing them | no | no | yes, on the admin dashboard |

A ticket has at most one link. Anyone allowed to share it manages that one
link (a requester can stop a link staff made, and the other way round).

## What a shared page shows

The requester's view of the ticket, read-only, without sign-in:

- number, subject, status (pill), "Opened by <requester name> <time>";
- the description and its files;
- the timeline entries that are not internal (`internal = false`): public
  replies with their author names, role labels and files, the `created`
  entry and status changes.

Shown since 2026-10-27 (operator: "next to In progress add who is working
on the ticket"): the assignee's display name next to the status pill, as
on the ticket page (ui.md "Ticket page"); staff names already appear on
their public replies, so this reveals nothing new.

Never shown: internal notes, internal events (priority, assignee changes,
sharing), priority, organization, any email address, the composer or any
form that changes the ticket. A note at the top says it is a read-only copy
shared by link.

The page shows the ticket as it is now: later public replies and status
changes appear on it; internal notes and internal events never do. Edited
text shows its current version with the "edited by" marker, never earlier
versions (timeline.md "Editing").

## Model

Columns on `tickets`: `share_token` (unique index, NULL when not shared),
`share_password_digest` (bcrypt via `has_secure_password :share_password,
validations: false`, NULL for an open link) and `shared_at`.

- `Ticket#share!(actor:, password: nil)` makes a new 32-character base58
  token (`SecureRandom.base58(32)`), sets or clears the password, sets
  `shared_at`. Sharing again replaces the link; the old one stops working.
- `Ticket#unshare!(actor:)` clears the three columns.
- A password is optional; when given it must be 6 to 72 characters
  (bcrypt's limit), otherwise nothing changes and an error is shown.
- The columns are written with `update_columns`: sharing is not activity on
  the ticket, so `updated_at` (last activity, queue order) does not change.
- Each share and unshare writes an internal ticket event (`shared`, with
  `to_value` "password" for a password link; `unshared`) in the same
  transaction, so staff see who shared or stopped sharing in the timeline
  ("Maria shared the ticket by link with a password"). These events send
  no email (notifications.md lists the kinds that do).

## Managing the link (ticket page)

A "Sharing" panel in the side column, for users allowed to share:

- not shared: one line on what a link shows ("Anyone with the link can
  read the description and the public replies, without signing in.
  Internal notes are never shown."), an optional password field and
  "Create share link" (`POST /tickets/:number/share`, param
  `share_password`);
- shared: since when, open link or link with password, the URL in a
  read-only field with a "Copy link" button (the field takes a row of
  its own in the narrow side column, the button under it, so the
  address stays readable; 2026-10-28) (clipboard; without JavaScript
  the field can be selected), "Stop sharing" (`DELETE
  /tickets/:number/share`, confirm dialog) and a collapsed "New link" form
  (same as create) to replace the link or change the password.

After a change: back to the ticket (`#sharing`) with a notice ("Share link
created." / "Sharing stopped."). An invalid password redirects back with
an alert.

Ticket lists (queue and My tickets) show a link icon with the label
"Shared by link" next to the subject of shared tickets.

## Link in the requester's emails (tickets from email)

Operator, 2026-10-28: a public reply emails the requester a link to
`/tickets/<number>`, which needs a sign-in that a customer who wrote by
email does not have. For a ticket with source `email`, the notification
emails to its requester (notifications.md) point to the shared page
instead, protected by the recipient's email address as password.

- **When the ticket has no link** as the email is queued
  (`TicketNotifier`, before the requester's email), the app shares it:
  `Ticket#share_with_requester!` calls `share!` with no actor (shown as
  the system in the timeline, internal `shared` event "with a password",
  like any share) and the requester's email address as password. Staff
  see the link in the Sharing panel and may stop or replace it; the next
  email to the requester then makes a new one only if no link exists.
- **Which link the email gives:** the shared page when the link is open
  or its password is the recipient's email address (checked with
  `authenticate_share_password` at sending time); then the email says
  that the password is the recipient's email address. A link with
  another password (set by staff) is not given: the email keeps the
  ticket page link, since the requester could not open it.
- Only the requester, only tickets with source `email`. Staff
  (assignee, subscribers) and requesters of tickets from the app or the
  public form keep the ticket page link.
- An address shorter than 6 or longer than 72 characters cannot be a
  share password (Model); then nothing is shared and the email keeps the
  ticket page link.
- **Typing the address:** the password form also accepts the address in
  other letter case or with spaces around it: when the given password
  contains `@`, `POST /s/:token` tries it as typed and then stripped and
  in lower case (Devise stores addresses in lower case). Other
  passwords are compared exactly.
- The shared page itself does not hint that the password is an email
  address; only the email says so.

Why the address as password: the 32-character token already is the
secret; the address only keeps a forwarded or leaked link from opening
the ticket for someone who does not know whose ticket it is. It is not a
strong secret, and the page shows nothing the requester's own emails did
not already carry.

## Visitor side (`/s/:token`, no sign-in)

| route | behaviour |
|-------|-----------|
| `GET /s/:token` | the shared page; for a password link not yet unlocked, the password form instead |
| `POST /s/:token` | check the password; on success remember the unlock in the session and redirect to the page; a wrong password re-renders the form with 422 |
| `GET /s/:token/files/:id` | download a file of the ticket or of one of its public replies (always as a download, as attachments.md) |

- An unknown, replaced or stopped token renders "Link not available" with
  404, the same for every reason.
- File routes of a locked link redirect to `/s/:token`.
- Files are looked up through the shared ticket and its public comments
  only, so a token never reaches another ticket's files or an internal
  note's files.
- The session stores, per token, a fingerprint of the password hash (the
  first 16 hex characters of its SHA-256). Changing the password or the
  link locks the page again. At most 20 unlocked tokens are kept per
  session.
- Password attempts are rate limited to 10 per 5 minutes per token (Rails
  `rate_limit`, in-process memory store); over the limit the form is shown
  with 429. The key is the token alone, not the IP: behind the production
  proxy chain the client IP is not yet confirmed (roadmap.md), and per
  token is what matters against guessing one link's password.
- A signed-in user who opens a link sees the same shared page; it does not
  use their account.

### Live updates of the shared page

Operator, 2026-10-26: "the shared ticket does not refresh". As in g0no, an
open shared page reloads itself within about a second when its public
content changes, keeping its scroll position (`turbo-refresh-scroll`
`preserve`):

- **Signal only.** The page subscribes with `turbo_stream_from
  *Ticket#share_stream` - the ticket, `:share` and a SHA-256 hash of the
  token, so the token itself stays out of Action Cable's logs and the
  signed stream name (signed, not encrypted). Since 2026-10-27 the
  subscription goes through `SharedTicketChannel` (ticket number as a
  parameter), which accepts only the current link's stream of a shared
  ticket and counts viewers (below). The server broadcasts only
  `<turbo-stream action="refresh">` (Turbo 8 page refresh, debounced by
  turbo-rails); the page fetches itself again over HTTP, so the token and
  the password unlock are checked as on any request.
- **When:** after a public (non-internal) timeline event is written - a
  public reply (with its files), a status change - and when the link is
  replaced or stopped (to the old token's stream, so an open page shows
  "Link not available"). Internal notes and internal events send nothing.
- A password page subscribes only after it is unlocked (the password form
  has no subscription).
- Visitors are not signed in, so Action Cable connections are open to
  anyone; streams are protected by their signed names, and the
  notification stream additionally only by its signed-in owner
  (notifications.md).

### Who is viewing now

Operator, 2026-10-27: "shared documents should show how many people are
viewing them right now, like a shared Google document". Visitors are not
signed in, so the indicator shows a number, never names:

- **Shared page:** next to the read-only note, an eye icon and "Only you
  are viewing" (1) or "3 people viewing now" (more). It counts open,
  unlocked shared pages of the current link, the reader's own included.
- **Ticket page, Sharing panel** (users allowed to share, when the ticket
  is shared): "Nobody has the link open now" / "1 person has the link
  open now" / "3 people have the link open now", so staff and the
  requester see whether the link is in use before stopping or replacing
  it.
- **Live:** both update within about a second when a shared page is
  opened or closed (tab closed, navigated away, connection lost).

How it works:

- The shared page subscribes to its existing share stream through
  `SharedTicketChannel` (a `Turbo::StreamsChannel` subclass, still no
  sign-in). Its `subscribed` callback adds one viewer for the link, its
  `unsubscribed` callback removes it. The count is kept per link (the
  SHA-256 of the token, as in the stream name) in process memory
  (`ShareViewers`, a `Concurrent::Map`), so it counts open pages (tabs),
  not people, and a replaced link starts from zero.
- After each change the count is broadcast as a custom stream action
  `<turbo-stream action="share_viewers" count="3">` to the share stream
  and to the ticket's page streams (`[ticket, :page, :staff]` and
  `:public`; the requester may share too). The number is the only
  content; the client picks the text from the page's own translations
  (`data-zero`, `data-one`, `data-other`). Pages render the current count
  on load, so a page refresh is also correct.
- The password form does not subscribe, so a locked visitor is not
  counted. Text is rendered by the client with `textContent`.
- **One process.** Action Cable runs in the web process with the `async`
  adapter (notifications.md), so web requests and channels share the
  count. A restart starts from zero and open pages count again as they
  reconnect. Several processes would need a shared store (solid_cable
  plus a database table, or Redis).

Response headers on `/s/...`:

- `Referrer-Policy: same-origin` - the token is not sent in `Referer` to
  other sites (`no-referrer` would make browsers send `Origin: null` on the
  password form, which fails Rails' CSRF origin check, as found in g0no).
- `X-Robots-Tag: noindex, nofollow` and `Cache-Control: no-store`.

## Admin

The admin dashboard lists shared tickets (number and subject linking to the
ticket, since when, open or with password) with a "Stop sharing" button for
each, so an administrator can see everything that is readable without
sign-in.

## Not in this phase

Link expiry dates, total view counts (history), names of viewers,
sharing internal content, several links per ticket. Recorded in
specs/roadmap.md.

## Acceptance

`test/models/ticket_share_test.rb` (token, replace, password length,
events, `updated_at` untouched) and
`test/controllers/shared_tickets_controller_test.rb` and
`test/controllers/ticket_shares_controller_test.rb`: open and password
links, wrong and short passwords, rate limit, replaced and stopped links,
unknown tokens (404), no internal note text, internal events or emails on
the shared page, files of internal notes and of other tickets not
reachable, who may share (requester own ticket only, 403 otherwise), the
admin list and the private headers.
`test/models/share_viewers_test.rb` and
`test/channels/shared_ticket_channel_test.rb`: counting per link, join
and leave broadcasts to the share and page streams, the indicator on both
pages.

## Security Note

Anyone who has an open link can read the ticket's public conversation and
download its files, without signing in; treat links like passwords, prefer
a password for sensitive tickets, and stop sharing when the link is no
longer needed. The token appears in the request path, so it is in server
access logs (Rails filters it only from the parameter log). The rate limit
is per process and resets on restart. Serve the app over HTTPS so links and
share passwords are not sent in clear text. The viewer count reveals only
how many pages of a link are open; anyone holding the link can inflate
it by opening many pages, so treat it as a hint, not an audit.
