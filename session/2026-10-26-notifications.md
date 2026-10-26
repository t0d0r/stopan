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
- Implemented it:
  - migration: `users.locale`, `users.notify_new_tickets`;
    `ApplicationController#remember_locale` stores a supported browser
    language of the signed-in user.
  - `TicketEvent` after create -> `TicketNotifier.collect`: events of one
    transaction are kept on the ticket object, one
    `current_transaction.after_commit` hands them over (works inside test
    transactions too); `TicketNotifier#notifications` picks recipients and
    kinds; `kind_for` decides the email.
  - `TicketMailer` (created, replied, noted, assigned, status_changed),
    one template in HTML and text, recipient's language, `References`
    header per ticket; re-checks deactivation and visibility at sending
    time and filters events with `TicketEvent.visible_to`.
  - account page "Notifications" form for staff, `PATCH
    /users/notifications` (`Users::NotificationsController`).
  - SMTP from `SMTP_*` in production (off without `SMTP_ADDRESS`, warning
    at boot), https links, `tmp/mails/` file delivery in development,
    `.env.example`, `compose.yaml` and specs/docker.md updated. Checked
    both production cases with `bin/rails runner` and throwaway values.
  - The text part of emails now prints user text unescaped (it was
    HTML-escaped by ERB); fixed in the reset password email too.
- Tests: test/models/ticket_notifier_test.rb (14),
  test/controllers/notifications_controller_test.rb (4). `make check`:
  151 runs, 0 failures.

## Decisions

- Active Job keeps Rails' in-process `:async` adapter in this phase; a
  durable queue (Solid Queue) is a later item. Lost emails on restart and
  no retries are accepted and documented.
- Nobody is emailed about their own action, including the requester who
  just opened a ticket.
- Without `SMTP_ADDRESS` production does not send email at all (no errors
  in requests).

## Open

- Production has no SMTP yet: the operator sets `SMTP_*` in the server's
  settings file (outside the repository) and redeploys; until then
  nothing is emailed, as before.
- Solid Queue for durable delivery (todo).
- Not deployed by this session.

## Files touched

specs/notifications.md, specs/README.md, specs/roadmap.md,
specs/data-model.md, specs/auth.md, specs/docker.md, todo/todo.md, this
note; db/migrate/20261026000001_*, db/schema.rb, app/models/{user,ticket,
ticket_event,ticket_notifier}.rb, app/mailers/*, app/views/ticket_mailer/*,
app/views/layouts/mailer.html.erb, app/views/devise/mailer/*.text.erb,
app/views/devise/registrations/edit.html.erb,
app/controllers/application_controller.rb,
app/controllers/users/notifications_controller.rb, config/routes.rb,
config/environments/{production,development,test}.rb,
config/locales/{en,bg}.yml, .env.example, compose.yaml, README.md,
test/models/ticket_notifier_test.rb,
test/controllers/notifications_controller_test.rb.

## How to verify

- `make check`.
- Development: `make run`, act as two users (for example the demo agent
  and requester), read the emails in `tmp/mails/`.

- Rate limiting by IP was considered and postponed: in production the
  client address passes Apache, pasta and Thruster, and it is not verified
  that Rails sees the real client IP; a wrong guess would turn a per-IP
  limit into a global one. Recorded as a todo with that check first.

## Next step

Next roadmap item: auto-close resolved tickets after N days (specs first;
needs a scheduler, which ties in with the Solid Queue todo).

## Security Note

Requester emails must never contain internal notes; the mailer itself
filters with `TicketEvent.visible_to`, and tests assert it. SMTP
credentials only come from the environment.
