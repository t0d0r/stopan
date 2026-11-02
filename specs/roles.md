# Roles and permissions

## Roles

`users.role` holds one of three values. New users (sign-up, admin form
default) are requesters.

| role | who | in short |
|------|-----|----------|
| `requester` | a customer contact | opens tickets for an organization they belong to; sees and works only on their own tickets (only public timeline entries) |
| `agent` | support staff | sees and works every ticket of the organizations they belong to |
| `admin` | super administrator ("Super administrator" in the interface) | every ticket of the organizations they belong to, like an agent; users, organizations, memberships and the settings of the whole service desk for every organization |

"Staff" means agent or admin (`User#staff?`).

An agent can also be an **organization administrator** of some of their
organizations (a mark on the membership): they manage those
organizations, their members and accounts, but no settings of the whole
service desk. Rules in org-admins.md.

A deactivated user (`users.deactivated_at` set) cannot sign in, whatever
the role, and cannot be chosen as assignee.

## Organizations and memberships

- A user belongs to zero or more organizations through `memberships`
  (unique per user and organization).
- A requester can only open tickets for an organization they belong to.
- **A requester or agent without a membership sees nothing** (operator,
  2026-10-27): after signing in they get only `GET /no-organization`, a
  small sticky saying the account is not part of an organization yet and
  to contact the service desk administrator, with a sign-out button.
  Every other page redirects there (JSON requests get 403), and the menu
  bar shows no sections, search or notification bell. Still allowed: the
  account pages (Devise), signing out, theme and text size, and an
  administrator's "Back to my account" while impersonating them. They are
  left out of administrators' messages. Once an administrator adds a
  membership, the next page works normally. Super administrators are
  never sent to that page, since they keep the admin area, but they see
  tickets only of their own organizations (below).
- **A requester sees only their own tickets** (operator, 2026-10-27:
  "a requester must see only their own tickets"): tickets whose requester
  they are, in an organization they are still a member of. Other
  members' tickets of the same organization are a 404 like any other
  ticket, everywhere (list, search, ticket page, files, notifications,
  live streams, magic links, email replies), all through
  `Ticket.visible_to`. Earlier the same day members could read their
  organization's tickets; that was reversed. They see the public part
  only: the description, public replies, public events and files, never
  internal notes or internal events. Removing a membership removes
  access to that organization's tickets at once.
- **Agents work their own organizations only** (operator, 2026-10-27:
  "agents should see only their own organizations"). An agent sees and
  works every ticket (internal notes included) of the organizations they
  are a member of, and nothing of the others: queue, board, search,
  ticket pages (404 for others), files, notifications, live streams and
  email replies all go through `Ticket.visible_to`.
- **Super administrators see tickets of their own organizations only**
  (2026-11-02: "a super admin who is not part of an organization must
  not see its tickets"). For tickets they are agents: queue, board,
  search, reports, ticket pages, files, notifications, live streams,
  shared links, deleted tickets and the API cover only organizations
  they are a member of; others are a 404. Before that day they saw every
  organization, member or not. The admin area still covers every
  organization (settings, members, users, mail, the danger zone), and
  the overview's counts stay totals of all tickets (numbers only, no
  subjects). To work an organization's tickets, a super administrator
  adds themselves as a member. **Reason:** an organization's tickets are
  read only by people who work for it; administering the service desk
  does not need their content.
- An agent creates tickets only in their own organizations, for
  requesters who are members of the chosen organization; the new ticket
  form lists only those organizations and requesters.
- A ticket can be assigned only to active staff (agent or super
  administrator) who are members of its organization
  (`Ticket#assignable_staff`; super administrators outside it since
  2026-11-02 no longer); assign
  menus, the Properties select and the queue's assignee filter list only
  those. Removing an agent's membership leaves their existing
  assignments in place; they no longer see those tickets until an
  administrator reassigns them (the admin list shows them).
- The queue and board filters list only the agent's organizations.

## Permission matrix

| action | requester | agent | admin |
|--------|-----------|-------|-------|
| sign in, edit own account | yes | yes | yes |
| list tickets | own tickets in own organizations ("My tickets") | queue of their organizations' tickets | same as agent |
| view a ticket (public part for requesters) | own ticket, in an organization they belong to | any ticket of their organizations | same as agent |
| see who is assigned (name only, ui.md "Ticket page") | tickets they can see, and on shared pages | yes | yes |
| see internal notes and internal events | no | yes | yes |
| create a ticket | for self, in own organization | for a member of one of their own organizations, in it | for any requester, in one of the requester's organizations |
| set priority / assignee on create | no | yes | yes |
| public reply | own ticket | any ticket | same as agent |
| internal note | no | any ticket | same as agent |
| edit the request's subject and description (timeline.md "Editing") | own ticket | any ticket | same as agent |
| edit a reply or note | own public reply on own ticket | any reply or note | same as agent |
| see earlier versions of edited text | no | yes | yes |
| attach files | to own ticket and own replies | to tickets, replies and notes | same as agent |
| download an attachment | only files on records they can see | any | any |
| change status | only "mark as done" on own new/open/pending/postponed ticket | any allowed transition (tickets.md) | same as agent |
| change priority, assignee | no | yes | yes |
| share a ticket by link (sharing.md) | own ticket, in own organization | any ticket | any ticket; also sees and stops the shared links of their organizations on the overview |
| open `/admin` | no | only an organization administrator, for their organizations (org-admins.md) | yes |
| impersonate another user (admin.md "Impersonation") | no | no | agents and requesters, not admins |
| manage users, roles, memberships, organizations | no | an organization administrator: their organizations, their members and accounts up to agent (org-admins.md) | yes |

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
- **Admin area.** `Admin::BaseController` redirects users who are neither
  super nor organization administrators to the start page with "Only
  administrators can open that page"; pages for super administrators only
  redirect organization administrators to the admin start (org-admins.md).
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
- A super administrator who is not a member of an organization does not
  see its tickets anywhere (queue, ticket page, search, board, reports,
  new ticket form, assignment, deleted tickets, the overview's shared
  list, notifications), yet opens its admin pages
  (`test/controllers/agent_scope_test.rb`).
- Tests: `test/policies/ticket_policy_test.rb`,
  `test/controllers/tickets_controller_test.rb`,
  `test/controllers/comments_controller_test.rb`,
  `test/controllers/attachments_controller_test.rb`,
  `test/integration/service_desk_flow_test.rb`.

## Security Note

Authorization failures for tickets are 404 by design. Do not add error
messages that reveal whether a ticket number exists.
