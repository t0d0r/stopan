# 2026-10-26 - phase 2: email notifications

Continues session/2026-10-26-phase1-followups.md. Stopan is meanwhile
deployed to production by a separate deployment session
(session/2026-10-25-deploy-stopan.md); this session does not deploy.

## Done

- Wrote specs/notifications.md: recipients, one email per person per
  action, the five kinds, visibility via `visible_to` (re-checked at
  sending time), language per user, staff "new tickets" opt-in, delivery
  after commit with `deliver_later`, SMTP from environment variables.
- Added the columns to specs/data-model.md, the spec to specs/README.md,
  marked the roadmap rows, and split the work into todo items.

## Decisions

- Active Job keeps Rails' in-process `:async` adapter in this phase; a
  durable queue (Solid Queue) is a later item. Lost emails on restart and
  no retries are accepted and documented.
- Nobody is emailed about their own action, including the requester who
  just opened a ticket.
- Without `SMTP_ADDRESS` production does not send email at all (no errors
  in requests).

## Open

- Implementation (todo, phase 2).

## Files touched

specs/notifications.md, specs/README.md, specs/roadmap.md,
specs/data-model.md, todo/todo.md, this note.

## How to verify

- `make check`.

## Next step

Migration for `users.locale` and `users.notify_new_tickets`, then
TicketNotifier and TicketMailer with tests.

## Security Note

Requester emails must never contain internal notes; the mailer itself
filters with `TicketEvent.visible_to`, and tests assert it. SMTP
credentials only come from the environment.
