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

Never shown: internal notes, internal events (priority, assignee, sharing),
priority, assignee, organization, any email address, the composer or any
form that changes the ticket. A note at the top says it is a read-only copy
shared by link.

The page shows the ticket as it is now: later public replies and status
changes appear on it; internal notes and internal events never do.

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
  read-only field with a "Copy link" button (clipboard; without JavaScript
  the field can be selected), "Stop sharing" (`DELETE
  /tickets/:number/share`, confirm dialog) and a collapsed "New link" form
  (same as create) to replace the link or change the password.

After a change: back to the ticket (`#sharing`) with a notice ("Share link
created." / "Sharing stopped."). An invalid password redirects back with
an alert.

Ticket lists (queue and My tickets) show a link icon with the label
"Shared by link" next to the subject of shared tickets.

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
  signed stream name (signed, not encrypted). The server broadcasts only
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

Link expiry dates, view counts, sharing internal content, several links per
ticket. Recorded in specs/roadmap.md.

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

## Security Note

Anyone who has an open link can read the ticket's public conversation and
download its files, without signing in; treat links like passwords, prefer
a password for sensitive tickets, and stop sharing when the link is no
longer needed. The token appears in the request path, so it is in server
access logs (Rails filters it only from the parameter log). The rate limit
is per process and resets on restart. Serve the app over HTTPS so links and
share passwords are not sent in clear text.
