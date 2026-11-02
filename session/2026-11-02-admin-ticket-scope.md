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

- Followers and Cc (specs/followers.md; README, roles.md, notifications.md,
  organization-mail.md, timeline.md, data-model.md and roadmap.md
  updated):
  - migrations `CreateTicketFollowers` (unique ticket and user; the
    adder is nullified when that user is deleted) and
    `AddDetailToTicketEvents`;
  - `TicketFollower`: active members of the organization, never the
    requester; the kind comes from the role;
  - `Ticket`:
    - `follow!`, `add_cc!` (finds or creates the requester and the
      membership, like mailbox mail; refuses staff, deactivated users,
      the requester and duplicates) and `remove_follower!`;
    - `cc_suggestions` from the mail headers;
    - `customer?`, `cc?`, `customer_emails`;
    - automatic follow for staff authors;
    - Cc lists refresh live;
  - `Ticket.visible_to` gives requesters their own tickets and their Cc
    tickets. `TicketFilter#own` follows it, and "My tickets" shows a "Cc"
    tag;
  - `TicketPolicy`: a Cc replies and edits their own public replies;
    resolve, edit and share stay with the requester;
  - `TicketNotifier` adds followers as candidates. The email switch
    covers every Cc. `TicketMailer` records customer mails with the
    address, and the reason or error goes in `detail`. Mail reasons
    `follower` and `cc` were added;
  - `MailboxMessage`: an email from a Cc becomes their public reply;
  - `TicketFollowersController` and the `_followers` panel (People).
    Follower events are internal and quiet;
  - tests:
    - `test/models/ticket_follower_test.rb`;
    - `test/controllers/ticket_followers_controller_test.rb`;
    - `test/integration/cc_access_test.rb`;
    - the mail record tests were updated.
    `make check` passes with 551 runs;
  - checked in the dev browser at 1440 and 390 px.

- In production, a person in Cc without a password got the ticket page
  link, which needs a sign-in. Fixed:
  - `Ticket#share_for_customer!` replaces `share_with_requester!`. The
    first email to a Cc makes the automatic link, protected by the
    requester's address;
  - `share_link_for` gives that link to the requester of a ticket from
    email and to every Cc;
  - the shared page also accepts a current Cc's own address on the
    automatic link (`customer_share_password?`), never on a password set
    by staff;
  - specs/followers.md and sharing.md updated, with tests.

- Deployed 99681ea, the shared link for people in Cc, with no
  migrations and every check passed (specs/deploy.md "Update 2026-11-02
  (revision 99681ea)"). An email sent before the fix still holds the
  ticket page link; the next public reply brings the shared link.

- Production backups: the 14 older copies were removed; only
  `pre-deploy-1fa5564.sqlite3` (before the follower migrations) remains.

- The shared page's password form has an eye button
  (`[data-password-field]`, `setUpPasswordField`, new `eye_off` icon):
  - it shows and hides what was typed, keeping the focus and the caret;
  - sending the form hides the text again;
  - the button is hidden without JavaScript, and is 44px on phones;
  - test in `shared_tickets_controller_test.rb`;
  - checked in the dev browser at 1440 and 390 px.

- Deployed 71df093 (the password eye), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision 71df093)").

- The password eye is now `ApplicationHelper#password_with_eye`, used on:
  - the shared page;
  - sign-in;
  - password reset (both fields);
  - the own account page (new, confirmation and current password).
  The spec moved to specs/ui.md "Password fields", the labels to
  `ui.password_show` / `ui.password_hide`, and the test is
  `test/integration/password_eye_test.rb`. Checked in the dev browser.

- The password eye is now a separate bordered button beside the field
  (flex row, the field's height, 44px on phones). Inside the field it
  covered the icons of password managers.

- Deployed 6a9194d (the password eye on sign-in and the password pages,
  beside the field), with no migrations and every check passed
  (specs/deploy.md "Update 2026-11-02 (revision 6a9194d)").

- Image preview (specs/attachments.md "Image size"):
  - the dialog takes the image's natural width up to the window, at
    least 480px;
  - an image is scaled down only when it does not fit;
  - a scaled image becomes a button for its actual size, with the media
    area scrolling;
  - PDFs and text keep the 960px dialog;
  - checked in the dev browser at 1920 and 390 px with a 2600 px and a
    420 px image.
- Backups: only `pre-deploy-1fa5564` remains in production (the rollback
  copy), so there was nothing older to remove.

- Deployed db88326 (image preview sizes), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision db88326)").

- Event lines between messages fold (specs/timeline.md "Event lines
  between messages fold"):
  - `TicketsHelper#timeline_entries` groups runs of 3 or more event
    lines; `created`, `status_changed`, `mail_failed`, `deleted` and
    `restored` stay visible and end a run;
  - `tickets/_event_run` renders the folded line ("9 events: emails,
    people, sharing", the staff-only tag, the newest time) and every
    line under it;
  - JavaScript (`setUpEventRuns`) folds the runs, keeps opened runs open
    across live refreshes and opens a run when a link points into it;
    without JavaScript and in print every line shows;
  - translations `ui.timeline.run` in en, bg and de;
  - tests in `test/helpers/tickets_helper_test.rb` and
    `test/controllers/tickets_controller_test.rb`;
  - checked in the dev browser at 1440 and 390 px: fold, open, live
    refresh, a link into a folded run.

- OpenSSF Scorecard (specs/ci.md):
  - `.github/workflows/scorecard.yml`: push to `main`, weekly, branch
    protection changes and by hand; `read-all` with
    `security-events: write` and `id-token: write` for the job; every
    action pinned to a commit SHA; results published and uploaded to
    code scanning;
  - README: the OpenSSF Scorecard badge and the workflow status badge;
  - `actionlint` passes on the workflow.

- Deployed 4c73f97 (folded event runs), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision 4c73f97)").

- Scorecard's first run on `main` passed and both badges show. The
  first score is 3.8:
  - 10: Token-Permissions, Binary-Artifacts, Dangerous-Workflow;
  - Pinned-Dependencies 2: every action is pinned, but the base images
    in `Dockerfile` (3) and `Dockerfile.dev` (1) are not pinned by
    digest;
  - 0: no SECURITY.md, no LICENSE, no SAST, no reviewed pull requests,
    no dependency update tool;
  - Maintained 0 until the repository is 90 days old.

- `SECURITY.md` (specs/ci.md "Security policy"): latest `main` only,
  reports through GitHub's private vulnerability reporting, what a
  report holds, acknowledgement normally within 7 days, testing rules.
  No personal address in it.
- Base images pinned by digest (specs/docker.md "Pinned base images"):
  - `Dockerfile` and `Dockerfile.dev` start from
    `docker.io/library/ruby@sha256:...` (the multi-platform index of
    `ruby:4.0.7-slim`), with the tag and the update steps in a comment;
  - the `# syntax=docker/dockerfile:1` line is pinned too;
  - the `RUBY_VERSION` build argument is gone;
  - digest only, without the tag, because Podman does not always accept
    both;
  - `test/config/dockerfile_test.rb` guards the pins, the same digest
    in both files and the version against `.ruby-version`.

- `LICENSE`: BSD 2-Clause (specs/overview.md "License"); the README has
  a License section and points to `SECURITY.md` for reports.

- Deployed 436dd64, built from the pinned base image, with no
  migrations and every check passed (specs/deploy.md "Update 2026-11-02
  (revision 436dd64)").
- Private vulnerability reporting is on in the repository settings.
- Scorecard after these changes: 5.1 (from 3.8). Pinned-Dependencies,
  License and Security-Policy are now 10; GitHub detects the license as
  BSD 2-Clause. Still 0: Maintained (repository younger than 90 days),
  Code-Review, Branch-Protection, SAST, Dependency-Update-Tool, Fuzzing,
  CII-Best-Practices.

## Decisions

- **Status changes, the opening line and failed emails never fold.** They
  mark the ticket's progress or need attention. Runs fold from 3 lines,
  since one or two lines take no more room than the folded line.

- **Followers come in two kinds, by role.** Staff followers see
  everything. Cc are customers who see the public part only. Mail
  headers suggest Cc addresses but never add them. Follower events are
  internal, so customers and shared pages never see who follows.

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

- Deployed 1fa5564 after a backup (`pre-deploy-28361df.sqlite3`); the
  migration ran and every check passed (specs/deploy.md "Update
  2026-11-02 (revision 1fa5564)").

- Deployed 018a5a2 after a backup (`pre-deploy-1fa5564.sqlite3`); both
  migrations ran and every check passed (specs/deploy.md "Update
  2026-11-02 (revision 018a5a2)").

## Open

- Pinned base images no longer pick up Debian fixes on their own; the
  digest is updated by hand until Dependabot is set up.
- A super administrator who works an organization's tickets adds
  themselves as a member on its page; until then they do not see them.

## Verify

`make check`.

## Next step

None pending; later items for followers are in todo.

## Security Note

Ticket content now reaches only members of the ticket's organization,
whatever the role. Impersonation remains the deliberate exception for
super administrators, and it is logged.
