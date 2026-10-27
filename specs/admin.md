# Administration

All under `/admin`, controllers in `app/controllers/admin/`, admins only
(roles.md). The menu bar shows "Admin" to admins only.

## Dashboard - `GET /admin`

Stat tiles: unsolved tickets, unassigned unsolved tickets, tickets solved
in the last 7 days, organizations, agents (agents + admins), requesters.
Links to the user and organization lists.

## Users - `/admin/users`

| route | behaviour |
|-------|-----------|
| `GET /admin/users` | table: name, username, email, role, organizations, status (active / deactivated), last sign-in, number of sign-ins (Devise's `sign_in_count`: every sign-in by password, magic link or remember-me cookie; impersonation does not count); actions as icon buttons with labels for screen readers and tooltips: edit (pencil), sign in as (only where impersonation is allowed, with the same confirm dialog as on the edit page) and Delete; filter by role, search by name/username/email; the role select applies on change and the search on Enter, with no Apply button (only a `<noscript>` one); a set role filter is highlighted (queues.md) |
| `GET /admin/users/new`, `POST /admin/users` | name, username, email, password + confirmation, role, organizations (checkboxes) |
| `GET /admin/users/:id/edit`, `PATCH /admin/users/:id` | same fields plus "Deactivated"; a blank password keeps the current one |
| `GET /admin/settings`, `PATCH /admin/settings` | automatic postponing (days), machine translation on/off (translation.md) and the board's stages per status (board.md) |
| `GET /admin/messages/new`, `POST /admin/messages` | send a message to a user, a role, an organization's members or everyone, shown in their notifications (notifications.md "Messages from administrators") |
| `DELETE /admin/users/:id` | only for users with no tickets (as requester or assignee), no comments and no ticket events; otherwise refused with "has ticket history; deactivate instead". The list shows the Delete button only for other users without history (`User.ids_with_ticket_history`, one query per table); the server check stays for requests made anyway |

Rules:

- An admin cannot change their own role, deactivate or delete themselves
  (fields disabled, parameters ignored, delete refused).
- Changing your own password keeps you signed in (`bypass_sign_in`).
- Usernames are unique case-insensitively; blank usernames are stored as
  NULL. Emails are unique (Devise).
- Demoting an agent who is assignee of unsolved tickets is allowed; those
  tickets become unassigned and each gets an `assignee_changed` event with
  the admin as actor.
- Deactivating a user also unassigns their unsolved tickets the same way.
- "Agent membership" is managed by setting the role: agents and admins are
  the staff list used for assignment.

## Organizations - `/admin/organizations`

| route | behaviour |
|-------|-----------|
| `GET /admin/organizations` | table: name, members, unsolved tickets, all tickets; search by name (Enter, no button) |
| `GET /admin/organizations/new`, `POST` | name (required, unique case-insensitively, at most 120 characters), notes (optional, staff-only text) |
| `GET /admin/organizations/:id` | details (with the public form's address and copy button when on, and the mailbox status: last check, messages taken in, last error), member list with role and "Remove", "Add member" (select of users not yet members) |
| `GET /admin/organizations/:id/edit`, `PATCH` | name, notes, URL name (`slug`), public form on/off and intro (public-form.md), the "Mail" panel with SMTP and mailbox settings (organization-mail.md) |
| `POST /admin/organizations/:id/mail_test` | send a test email through the organization's SMTP to the signed-in admin |
| `POST /admin/organizations/:id/mailbox_check` | log in to the organization's mailbox and report the unseen count |
| `DELETE /admin/organizations/:id` | only without tickets; memberships are removed with it |
| `POST /admin/organizations/:id/memberships` | add a member (`user_id`) |
| `DELETE /admin/memberships/:id` | remove a member; their access to that organization's tickets ends at once |

Destructive actions ask in the confirm dialog, naming what will be lost.

## Impersonation

Requested by the operator on 2026-10-27 ("admin to have option:
impersonate"): an administrator can see and use the app as another user,
to check what they see or help them.

- "Sign in as <name>" on the user's admin edit page, with a confirm
  dialog: `POST /admin/users/:id/impersonation`. Only for active agents
  and requesters: never for administrators (no taking over an equal
  account), deactivated users or oneself (403).
- The session keeps the administrator's id (`session[:impersonator_id]`)
  and signs in the user with Devise's `bypass_sign_in`, so the user's
  own sign-in times stay untouched (their magic links stay valid, the
  admin list's "last sign-in" stays true).
- Every page then shows a red banner under the menu bar: "You are signed
  in as Anna Petrova (Requester) by impersonation." with "Back to my
  account" (`DELETE /impersonation`), which signs the administrator back
  in and opens that user's admin page. Signing out ends both.
- While impersonating, everything is done as the user (replies, status
  changes appear under their name), except the account page: changing
  their name, email or password is refused with a notice.
- Every impersonation is recorded in `impersonations` (administrator,
  user, started at, ended at, IP); the user's admin edit page lists the
  last ten, and the log has a line for start and end. The records are
  never deleted in the app.

## Live updates

Operator, 2026-10-26: "the admin pages should refresh live too". Every
open admin page (dashboard, users, organizations, their forms) reloads
itself within about a second when its data may have changed, keeping its
URL and scroll position:

- **Stream `[:admin]`**, told after a user, organization or membership is
  created, changed or deleted (sign-ins and lockouts change users too, so
  "last sign-in" stays current) and after every ticket event (the
  dashboard's counts, busiest organizations and shared tickets).
- `AdminChannel` accepts it only for administrators.
- Signal only (`<turbo-stream action="refresh">`, debounced per stream);
  the page is fetched again over HTTP with the admin check.
- A refresh waits while the page is busy (typed or changed fields, a
  focused field, the confirm dialog or a menu open), as on the ticket page
  (timeline.md), so a half-filled user or organization form is never
  reset. A page of a record deleted meanwhile shows "not found" after the
  refresh.

## Acceptance

`test/controllers/admin/*_test.rb`: access control, CRUD, self-protection,
delete refusal with history, unassignment on demotion/deactivation,
membership add/remove; `impersonations_controller_test.rb`: who may be
impersonated, the banner, the way back, sign-in times untouched, the
account page locked, the records.

## Security Note

Admins can set passwords and grant roles. Keep the number of admins small
and keep the seeded admin password (in `.env`) private. Impersonation lets
an admin act under another user's name: it is recorded with time and IP,
shown in a banner the whole time, cannot reach other admins or the
user's own credentials, and should be used only to help that user.
