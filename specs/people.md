# Person profile with statistics

Operator, 2026-10-27: "from 'Requester' when reading a ticket, open the
requester's profile with statistics".

## Who and where

- `GET /people/:id`, staff only (requesters get 403). An administrator may
  open anyone; an agent only people who share an organization with them
  (404 otherwise), as agents work their own organizations only
  (roles.md).
- On the ticket page the requester's name in the Requester panel links
  to it (staff only).
- API: `GET /api/v1/people/:id` with the same rule and the same numbers
  (api.md).

## Page

- **Header:** avatar, name, role label, a "Deactivated" tag when so, the
  email (mail link), the organizations, "Member since", "Last sign in"
  (or "Never").
- **Tiles** (as on the reports page), over the tickets the person
  requested that the viewer may see (`Ticket.visible_to(viewer)`):
  tickets in total, unsolved now, done, opened in the last 30 days,
  median first response (from opening to the first public reply by
  staff) and median time to done (opening to `done_at`, done tickets
  only). Medians show "-" when there is nothing to measure; durations
  read like "3 h 20 min" or "2 d 4 h".
- **How they write in:** counts per source - app, web form, email.
- **Latest tickets:** the ten most recently active, one line each
  (number, subject, organization, status, last activity), and "All
  tickets from this person" to the queue filtered by requester
  (`/tickets?view=all&requester=<id>`, queues.md "Filters").

## Queue filter

The queue takes `requester=<user id>` (staff): only tickets of that
requester. It shows as a removable chip "Requester: Name" in the filter
bar, is kept by the other filters, the search and the bulk bar's "whole
list", and counts as a filter for "Clear filters".

## Security Note

The profile shows only what the viewer may already see: tickets come
from `Ticket.visible_to(viewer)`, so an agent's numbers cover only their
organizations, and agents cannot open people outside their
organizations. Requesters have no profile pages of others.
