# 2026-11-02 - super administrators see only their organizations' tickets

## Done

- Production: two super administrators became agents with the
  organization admin mark on their only organization (recorded in
  session/2026-10-29-org-admins.md).
- Super administrators now see tickets only of organizations they are a
  member of (specs/roles.md "Super administrators see tickets of their
  own organizations only"). Specs also updated: org-admins.md,
  tickets.md "Deleting", sharing.md "Admin", presence.md, api.md.
- Code:
  - `Ticket.visible_to` no longer has an exception for admins.
  - `User#visible_organizations` returns the user's own organizations.
  - `Ticket.assignable_staff` returns the organization's active staff;
    the assignee validation needs membership for admins too.
  - `TicketsController#create` limits new tickets to own organizations
    for every staff role.
  - `find_ticket_for_page` covers deleted tickets through `AdminScope`
    for both kinds of administrator.
  - `AdminScope#deleted_tickets`: a super administrator's own
    organizations. The API's deleted tickets use the same scope.
  - The overview's shared list is limited to visible tickets.
  - The presence requester count is limited to the reader's
    organizations for everyone.
  - The ticket table's assign menu offers the organization's staff.
- Tests:
  - fixtures: the test admin is a member of both organizations
    (`admin_acme`, `admin_globex`);
  - new tests in `test/controllers/agent_scope_test.rb`: a super
    administrator outside an organization, and one getting no
    notifications;
  - `ticket_test.rb` visible_to, the report, seeds and org admin tests
    adjusted.

- Emails to the requester (specs/notifications.md "Emails to the
  requester", timeline.md "Events", data-model.md):
  - `tickets.email_requester`, migration `AddEmailRequesterToTickets`,
    default on;
  - in the composer, for staff while "Public reply" is chosen, an "Email
    the requester" toggle (`role=switch`). It saves at once through
    `RequesterMailsController#update` (POST with `_method=patch`, Turbo
    fetch). Without JavaScript it comes with the reply
    (`CommentsController#create`). The warning under it names the
    address and says the mail leaves Stopan;
  - `Ticket#switch_requester_mail!` writes `mail_switched`;
  - `TicketNotifier` skips the requester's email when the switch is off
    and records `mail_skipped switched_off`. The in-app notification
    still goes, and no share link is made;
  - `TicketMailer` records `mail_sent` (`after_deliver`),
    `mail_skipped no_smtp` (message not performed) and `mail_failed`
    (`rescue_from` while delivering, logged, not raised), only for the
    requester;
  - mail events skip `TicketNotifier.collect`;
  - tests: `test/models/requester_mail_test.rb` and
    `test/controllers/requester_mails_controller_test.rb`;
  - checked in the dev browser: on, off, and the event after a reload.

## Decisions

- **The email switch is per ticket, not per reply.** It saves at once,
  with no save button, and covers every email to the requester: new
  tickets opened for them, replies and status changes. Staff emails are
  not affected.
- **Only emails to the requester are recorded in the timeline.** They are
  the mail that leaves for the customer.

- **The admin area stays global.** Settings, users, organizations, mail
  and the danger zone still cover every organization. The overview's
  counts stay totals of all tickets: numbers only, no content. Only
  ticket content follows membership.
- **Super administrators keep "Sign in as".** An agent's session shows
  that agent's tickets, so it is still a way to read them. That is
  impersonation as admin.md defines it; it was left unchanged.
- **Super administrators are still never sent to the no-organization
  page**, because they need the admin area. Without memberships their
  queue is empty.

## Open

- Deploy the email switch (migration `AddEmailRequesterToTickets`).

- Deploy. Before or right after, a super administrator who works an
  organization's tickets adds themselves as a member on its page.

## Verify

`make check`.

## Next step

Deploy when requested.

## Security Note

Ticket content now reaches only members of the ticket's organization,
whatever the role. Impersonation remains the deliberate exception for
super administrators, and it is logged.
