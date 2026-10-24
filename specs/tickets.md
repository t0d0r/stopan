# Tickets

## Fields

| field | rule |
|-------|------|
| `number` | integer, unique, assigned on create, never changes; the first ticket is 1001, each new one is the highest number + 1. Rails 8 opens SQLite write transactions as IMMEDIATE, so reading the maximum and inserting happen under the write lock; the unique index is the backstop. Shown as `#1001`; URLs use it: `/tickets/1001` (`Ticket#to_param`) |
| `subject` | required, stripped, at most 200 characters |
| `description` | required, at most 20,000 characters, plain text |
| `status` | `new`, `open`, `pending`, `resolved`, `closed`; default `new` |
| `priority` | `low`, `normal`, `high`, `urgent`; default `normal` |
| `requester_id` | required; the user must be a member of the ticket's organization |
| `assignee_id` | optional; must be an active agent or admin |
| `organization_id` | required |
| `created_at`, `updated_at` | Rails timestamps; `updated_at` is touched by every event, so it is the "last activity" time |
| `resolved_at`, `closed_at` | set when the ticket enters that status, cleared when it is reopened |
| files | up to 5 attachments added on create (attachments.md) |

## Status meaning

| status | meaning | who usually sets it |
|--------|---------|---------------------|
| new | not triaged yet | system, on create |
| open | an agent is working on it | agent, or system on a reply |
| pending | waiting for the requester | agent |
| resolved | a solution was given; the requester can still reply, which reopens it | agent or requester |
| closed | finished; no more public replies | agent |

"Unsolved" means new, open or pending. "Solved" means resolved or closed.

## Transitions

Allowed manual changes by staff (`Ticket::TRANSITIONS`):

| from | to |
|------|----|
| new | open, pending, resolved, closed |
| open | pending, resolved, closed |
| pending | open, resolved, closed |
| resolved | open, closed |
| closed | open |

Nothing goes back to `new`. Setting the same status is a no-op and records
nothing. An invalid transition is a validation error on `status`.

Automatic changes, recorded as status events with the replying user as
actor:

- A requester's public reply on a `pending` or `resolved` ticket sets it to
  `open`.
- A staff public reply on a `new` ticket sets it to `open`, unless the reply
  form chose another status ("Submit as ...").
- A staff reply or note may choose any allowed status in the same request.

Requester action: "Mark as resolved" on their own ticket in `new`, `open` or
`pending` sets `resolved`.

Closed tickets accept no public replies from anyone. Staff can still add
internal notes and reopen the ticket (`closed` -> `open`).

## Creating

- **Requester** form: subject, description, organization (a select only when
  they belong to more than one; otherwise their single organization is
  used), files. Status `new`, priority `normal`, no assignee.
- **Staff** form: the same plus requester (active users with at least one
  membership), organization, priority and assignee. The server checks that
  the requester belongs to the organization.
- After create: redirect to the ticket with "Ticket #1001 was created."
- A `created` event is written in the same transaction (timeline.md).

## Updating (staff)

`PATCH /tickets/:number` with any of `status`, `priority`, `assignee_id`.
Each changed field writes one event; all changes and events are saved in
one transaction, or none on a validation error (422 re-renders the ticket
page with the errors). Requesters get 403.

`PATCH /tickets/:number/resolve` is the requester's "Mark as resolved"
(also allowed for staff).

## Deleting

Tickets are not deleted in this phase (audit history must stay complete).
Roadmap: spam deletion by admins with an audit entry.

## Acceptance

`test/models/ticket_test.rb` covers numbering, validations, the transition
table, timestamps and the automatic reopen rules;
`test/controllers/tickets_controller_test.rb` covers create and update per
role.

## Security Note

Subjects and descriptions are user input; they are always rendered escaped
(`simple_format` over escaped text) and never used in SQL without binding.
