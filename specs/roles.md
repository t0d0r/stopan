# Roles and permissions

## Roles

`users.role` holds one of three values. New users (sign-up, admin form
default) are requesters.

| role | who | in short |
|------|-----|----------|
| `requester` | a customer contact | opens tickets for an organization they belong to; sees the tickets of their organizations (only public timeline entries), works only on their own |
| `agent` | support staff | sees and works every ticket of every organization |
| `admin` | service desk administrator | everything an agent can, plus users, organizations and memberships |

"Staff" means agent or admin (`User#staff?`).

A deactivated user (`users.deactivated_at` set) cannot sign in, whatever
the role, and cannot be chosen as assignee.

## Organizations and memberships

- A user belongs to zero or more organizations through `memberships`
  (unique per user and organization).
- A requester can only open tickets for an organization they belong to. A
  requester without a membership sees a message asking them to contact an
  administrator, and the create action refuses.
- A requester sees a ticket while they are a member of its organization
  (operator, 2026-10-27: members of an organization get its new tickets
  in their notifications and can read them). Before that change only the
  ticket's own requester could see it. They see the public part only:
  the description, public replies, public events and files, never
  internal notes or internal events. Removing a membership removes access
  to that organization's tickets at once.
- On a colleague's ticket a requester reads only: replying, marking as
  resolved, editing, Markdown switches and sharing stay with the ticket's
  own requester (`TicketPolicy#own?`) and staff. The page says so where
  the composer would be.
- Staff can be members of organizations (for example to raise tickets
  themselves), but membership does not limit what staff can see.

## Permission matrix

| action | requester | agent | admin |
|--------|-----------|-------|-------|
| sign in, edit own account | yes | yes | yes |
| list tickets | own tickets in own organizations ("My tickets") | queue of all tickets | queue of all tickets |
| view a ticket (public part for requesters) | any ticket of an organization they belong to | any | any |
| see who is assigned (name only, ui.md "Ticket page") | tickets they can see, and on shared pages | yes | yes |
| see internal notes and internal events | no | yes | yes |
| create a ticket | for self, in own organization | for any requester, in one of the requester's organizations | same as agent |
| set priority / assignee on create | no | yes | yes |
| public reply | own ticket, not closed | any ticket, not closed | same as agent |
| internal note | no | any ticket (also closed) | same as agent |
| edit the request's subject and description (timeline.md "Editing") | own ticket, not closed | any ticket | same as agent |
| edit a reply or note | own public reply on own ticket, not closed | any reply or note | same as agent |
| see earlier versions of edited text | no | yes | yes |
| attach files | to own ticket and own replies | to tickets, replies and notes | same as agent |
| download an attachment | only files on records they can see | any | any |
| change status | only "mark as resolved" on own new/open/pending ticket | any allowed transition (tickets.md) | same as agent |
| change priority, assignee | no | yes | yes |
| share a ticket by link (sharing.md) | own ticket, in own organization | any ticket | any ticket; also sees and stops every shared link |
| open `/admin` | no | no | yes |
| impersonate another user (admin.md "Impersonation") | no | no | agents and requesters, not admins |
| manage users, roles, memberships, organizations | no | no | yes |

## Enforcement

- **Scopes first.** Controllers load tickets only through
  `Ticket.visible_to(user)`; a ticket outside the scope raises
  `ActiveRecord::RecordNotFound` (404). The timeline uses
  `TicketEvent.visible_to(user)`, which adds `internal = false` for
  requesters.
- **Policy checks second.** `TicketPolicy` answers `reply?`, `note?`,
  `update?`, `resolve?` and `assign_to?(user)`. A visible ticket with a
  forbidden action answers 403 with a short translated page
  (`ApplicationController#forbidden`), and nothing is changed.
- **Strong parameters per role.** Requester parameters never include
  `status`, `priority`, `assignee_id`, `requester_id` or `internal`; if sent,
  they are ignored (an `internal` flag from a requester is forced to false).
- **Model validations** back the rules that must hold whatever the caller:
  requester is a member of the ticket's organization, assignee is active
  staff, status and priority are in their lists, the status transition is
  allowed.
- **Admin area.** `Admin::BaseController` redirects non-admins to the start
  page with "Only administrators can open that page".
- **Self-protection.** An admin cannot change their own role, deactivate or
  delete themselves, so at least one admin remains.

## Acceptance

- Requester A cannot open, reply to, download from or even confirm the
  existence of a ticket of requester B, in the same or another organization
  (404 each time).
- A requester's ticket page and JSON-free HTML never contain the body of an
  internal note or an internal event (assignee or priority change).
- A requester posting `internal=1` creates a public reply.
- A requester posting status, priority or assignee changes changes nothing.
- An agent can open `/tickets` (queue) but not `/admin`.
- Tests: `test/policies/ticket_policy_test.rb`,
  `test/controllers/tickets_controller_test.rb`,
  `test/controllers/comments_controller_test.rb`,
  `test/controllers/attachments_controller_test.rb`,
  `test/integration/service_desk_flow_test.rb`.

## Security Note

Authorization failures for tickets are 404 by design. Do not add error
messages that reveal whether a ticket number exists.
