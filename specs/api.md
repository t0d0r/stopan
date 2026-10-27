# JSON API with personal tokens

Operator, 2026-10-27: "make an API with tokens, every user makes their
own token, and can use all functions through the API". roadmap.md had it
as a later phase.

## Principles

- **Same rights as the web app.** A token acts as its user. Every
  request goes through the same scopes and checks as the pages:
  `Ticket.visible_to`, `Comment.visible_to`, `TicketEvent.visible_to`,
  `Notification.visible_to`, `TicketPolicy`, the admin-only rule, and
  the strong parameters per role (roles.md). Outside the scope is 404,
  a forbidden action 403, invalid input 422.
- **The same model methods** as the pages (`apply_changes`,
  `add_comment`, `edit`, `share!`, `Translation.translate!`, ...), so
  events, notifications, emails and live page refreshes happen exactly
  as when a person clicks.
- Versioned under `/api/v1`, JSON in and out (`Content-Type:
  application/json`; file uploads as `multipart/form-data`). Dates are
  ISO 8601 in UTC. Tickets are addressed by their number, as in the app.

## Tokens

- Table `api_tokens`: `user_id`, `name` (1 to 60 characters),
  `token_digest` (SHA-256 of the token, unique), `token_hint` (the last
  4 characters, to tell tokens apart), `expires_at` (optional),
  `last_used_at`, timestamps. The token itself is never stored.
- A token is `stopan_` followed by 40 random base58 characters. It is
  shown once, right after it is made.
- **Read-only** (operator, 2026-10-27: "the token should have a
  Read-only option when created"): a check box when making a token
  (`api_tokens.read_only`). A read-only token may only use `GET`; any
  other method answers 403 `{"error":{"code":"read_only",...}}`, even
  revoking tokens. `GET` requests change nothing (reading a ticket
  through the API does not mark its notifications read). The list on
  the account page and `GET /api/v1/tokens` show "Read-only" or "Read
  and write".
- **Account page, "API tokens"** (every user, staff or requester): a
  form with a name and an expiry (never, 30, 90 or 365 days), the list
  of the user's tokens (name, "...hint", created, last used, expires)
  with "Revoke" (confirmation). At most 10 tokens per user. Not while an
  administrator impersonates the user (admin.md "Impersonation"): the
  section says so and creating is refused.
- **Using it:** `Authorization: Bearer <token>`; no token in the query
  string. Unknown, expired or revoked tokens, and tokens of deactivated
  users, answer 401 `{"error":{"code":"unauthorized",...}}` with
  `WWW-Authenticate: Bearer`. `last_used_at` is updated at most once a
  minute.
- A user without a membership (roles.md) gets 403 on everything but
  `GET /api/v1/me`, as on the pages.
- Removing a user removes their tokens; deactivating stops them at once.
- Tokens cannot be created through the API (a stolen token cannot make
  more); `GET /api/v1/tokens` lists the user's own tokens (no secrets)
  and `DELETE /api/v1/tokens/:id` revokes one, including the one in use.
- Rate limit: 300 requests a minute per token; then 429 with
  `Retry-After`.

## Errors

`{"error": {"code": "<code>", "message": "<text in the user's language>",
"details": {"<field>": ["..."]}}}` with codes `unauthorized` (401),
`forbidden` (403), `read_only` (403, a write with a read-only token),
`not_found` (404), `bad_request` (400, a missing
top-level key), `invalid` (422, with `details` from the validation
errors), `rate_limited` (429).

## Endpoints

Everyone (within their rights):

| method and path | what |
|---|---|
| `GET /api/v1/me` | the user: id, name, email, role, language, organizations |
| `PATCH /api/v1/me` | `language` (en, bg, de); staff also `notify_new_tickets` |
| `GET /api/v1/tickets` | the list, as the queue or "My tickets": `view`, `status`, `priority`, `assignee` (staff), `organization` (staff), `q`, `sort`, `page`; 25 per page with `page`, `total_pages`, `total_count` |
| `POST /api/v1/tickets` | new ticket: `ticket[subject, description, markdown, organization_id]`, staff also `requester_id, priority, assignee_id`; `ticket[files][]` as multipart; 201 |
| `GET /api/v1/tickets/:number` | the ticket with its visible timeline (events with their comments), files, share state (for who may share), `mail_headers` (staff) |
| `PATCH /api/v1/tickets/:number` | staff: `ticket[status, priority, assignee_id, stage_id]` |
| `POST /api/v1/tickets/:number/resolve` | the requester's "Mark as done" |
| `DELETE /api/v1/tickets/:number` | staff who may update it: soft delete (tickets.md "Deleting"); 204 |
| `PATCH /api/v1/tickets/bulk` | staff: `numbers[]` or `scope=list` with the list filters (`view, status, priority, assignee, organization, q`), and `changes[status, priority, assignee]` (`me`, `none` or a user id); returns `updated` (numbers) and `skipped` (number and reason) (queues.md "Bulk actions") |
| `PATCH /api/v1/tickets/:number/description` | `ticket[subject, description]` (an edit with a revision) and/or `ticket[markdown]` (the switch) |
| `PATCH /api/v1/tickets/:number/description/task` | `line`, `checked` (Markdown task lists) |
| `GET /api/v1/tickets/:number/comments` | visible replies and notes |
| `POST /api/v1/tickets/:number/comments` | `comment[body, internal, markdown, status]` (internal and status for staff), `comment[files][]`; 201 |
| `PATCH /api/v1/tickets/:number/comments/:id` | `comment[body]` and/or `comment[markdown]` |
| `PATCH /api/v1/tickets/:number/comments/:id/task` | `line`, `checked` |
| `GET /api/v1/tickets/:number/attachments/:id` | the file, as a download |
| `GET /api/v1/tickets/:number/revisions` | staff: earlier versions of the request and comments |
| `POST /api/v1/tickets/:number/revisions/:id/restore` | staff |
| `POST /api/v1/tickets/:number/share` | `password` (optional); returns the link |
| `DELETE /api/v1/tickets/:number/share` | stop sharing |
| `POST /api/v1/tickets/:number/translations` | staff, when translation is on: `message` (`description` or `comment-<id>`), `language` (default the user's); returns the text |
| `GET /api/v1/notifications` | own notifications, newest first, 50 a page |
| `POST /api/v1/notifications/:id/read`, `POST /api/v1/notifications/read_all` | mark read |
| `GET /api/v1/reports` | staff: the report of reports.md for `period` and `organization` (tiles, buckets, burndown, rows) |
| `GET /api/v1/stages` | staff: the board's stages |
| `GET /api/v1/people/:id` | staff: a person's profile and ticket statistics (people.md) |
| `GET /api/v1/tokens`, `DELETE /api/v1/tokens/:id` | own tokens |

Administrators only (403 for others):

| method and path | what |
|---|---|
| `GET/POST /api/v1/users`, `GET/PATCH/DELETE /api/v1/users/:id` | as /admin/users: `user[name, username, email, password, role, deactivated, organization_ids]`; the same self-protection; a user with ticket history cannot be deleted |
| `GET/POST /api/v1/organizations`, `GET/PATCH/DELETE /api/v1/organizations/:id` | as /admin/organizations, mail settings included; passwords write-only, never returned |
| `POST /api/v1/organizations/:id/mail_test`, `POST /api/v1/organizations/:id/mailbox_check` | the two test buttons |
| `POST /api/v1/organizations/:id/memberships` (`user_id`), `DELETE /api/v1/memberships/:id` | members |
| `GET/PATCH /api/v1/settings` | `auto_postpone_days, default_look, mailbox_polling, mailbox_poll_seconds, timeline_order, translation_enabled, deepl_api_key` (write-only; `deepl_api_key_set` tells whether one is stored) |
| `POST/PATCH/DELETE /api/v1/stages[/:id]`, `POST /api/v1/stages/:id/move` (`direction` up/down) | board stages |
| `POST /api/v1/messages` | `recipients`, `text`: a message to users' notifications |
| `GET /api/v1/deleted_tickets`, `POST /api/v1/deleted_tickets/:number/restore` | deleted tickets and restoring one (tickets.md "Deleting") |

Not in the API, as they need a browser: signing in and passwords
(Devise), the Google connection and wizard, impersonation, themes and
other browser preferences, creating tokens.

## Representations

- **User (short):** `id, name, role` (and `email` for staff, and for the
  user themself).
- **Ticket:** `number, reference, subject, status, priority, source,
  markdown, stage {id, name}, organization {id, name}, requester,
  assignee, created_at, updated_at, done_at, edited_at, url` (the page);
  in `show` also `description, files, timeline, shared` (and
  `share_url` when shared and the user may share), `mail_headers` (staff)
  and `next_statuses` (staff).
- **Comment:** `id, body, internal, markdown, source, author,
  created_at, edited_at, files`.
- **Event:** `id, action, from, to, internal, actor, created_at,
  comment` (for replies and notes).
- **File:** `id, filename, content_type, byte_size, url` (the API
  download path).
- Requesters never get internal notes, internal events, `mail_headers`
  or other users' emails.

## Acceptance

- A request without a token, with a wrong one, an expired one or one of
  a deactivated user is 401; a revoked token stops at once.
- A requester's token sees only their own tickets (others are 404), may
  not write internal notes (an `internal` flag becomes a public reply),
  cannot change status, priority or assignee (403) and gets 403 on admin
  endpoints.
- An agent's token sees only their organizations' tickets.
- Creating a ticket or reply through the API sends the same
  notifications and records the same events as the web app.
- The token is shown once and only its digest is stored.

## Security Note

A token is as strong as its user's password and skips the sign-in
form, so it is shown once, kept only as a SHA-256 digest, can expire,
and is revoked from the account page or the API. Tokens never travel in
URLs (they would land in logs). The API has no cookies and no session,
so there is no CSRF surface; it follows the same scopes as the pages so
requesters cannot reach internal content. Responses carry no mailbox
passwords, OAuth secrets or DeepL keys. Logs record the token id, never
the token.
