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
| `GET /admin/users` | table: name, username, email, role, organizations, status (active / deactivated), last sign-in; filter by role, search by name/username/email; the role select applies on change and the search on Enter, with no Apply button (only a `<noscript>` one); a set role filter is highlighted (queues.md) |
| `GET /admin/users/new`, `POST /admin/users` | name, username, email, password + confirmation, role, organizations (checkboxes) |
| `GET /admin/users/:id/edit`, `PATCH /admin/users/:id` | same fields plus "Deactivated"; a blank password keeps the current one |
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
| `GET /admin/organizations/:id` | details, member list with role and "Remove", "Add member" (select of users not yet members) |
| `GET /admin/organizations/:id/edit`, `PATCH` | name, notes |
| `DELETE /admin/organizations/:id` | only without tickets; memberships are removed with it |
| `POST /admin/organizations/:id/memberships` | add a member (`user_id`) |
| `DELETE /admin/memberships/:id` | remove a member; their access to that organization's tickets ends at once |

Destructive actions ask in the confirm dialog, naming what will be lost.

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
membership add/remove.

## Security Note

Admins can set passwords and grant roles. Keep the number of admins small
and keep the seeded admin password (in `.env`) private.
