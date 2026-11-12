# Status page

2026-11-12: "Is there a way to see status or errors through the admin
dashboard? Jobs in the queues, the outcome of their work?" Until now
an administrator saw only the last check and last error of a mailbox
on the organization's page; why a mail did not become a ticket, or
whether an email was sent, was only in the server's log.

`GET /admin/status`, a tab "Status" after "Settings", for super
administrators only. It is read-only apart from two buttons, and
reloads live with the other admin pages.

## Mail in

- One line for the whole desk: automatic fetching on or off, and how
  often (organization-mail.md "Fetching").
- One row per organization with a mailbox switched on: last check,
  messages taken in so far, last error (red), and "Check the mailbox"
  (the button of the organization page).
- **Mail log:** the last 50 messages the mailboxes took in, newest
  first: time, organization, sender, subject, and what became of it:

  | result | shown as |
  |---|---|
  | `ticket` | "New ticket #1042" (link) |
  | `reply` | "Reply on #1042" (link) |
  | `skipped` | "Skipped: automatic mail", "... no sender", "... the mailbox's own address" |
  | `ignored` | "Ignored: staff sender without a ticket", "... deactivated sender", "... agent outside the ticket's organization" |
  | `failed` | "Failed: <error class>" |

  This answers "why is there no ticket": for instance a mail sent
  from a staff member's own address never opens a ticket (staff answer
  by mail, they do not start tickets that way).
- Kept in `mailbox_events` (`organization_id`, `result`, `reason`,
  `sender`, `subject` cut at 150, `ticket_id`, `created_at`); written
  by `MailboxMessage#process` for every message and by `MailboxCheck`
  when a message raises. The newest 200 per organization are kept;
  older rows go when a new one is written. Deleting or flushing an
  organization removes its rows.

## Job queue

Emails, live page refreshes and webhook calls run as jobs
(notifications.md "Delivery").

- Counts: waiting, scheduled for later, running now, failed, and
  finished in the last 24 hours.
- **Failed jobs** (newest 20): what it was, when, and the error (class
  and message, cut at 300). A job that fails is retried first; it
  lands here only when its tries are used up. Buttons "Try again" and
  "Discard" for each (confirm on Discard).
- **Recent jobs** (newest 30 finished): what it was and when it
  finished. So "was the email sent" has an answer.
- "What it was" is the job's name in plain terms: an email shows its
  mailer and kind ("TicketMailer replied"), a webhook its event, any
  other job its class. **Arguments are never shown**: they hold
  addresses and record ids.
- Finished jobs are now kept for 2 days
  (`preserve_finished_jobs` on, `clear_finished_jobs_after` 2 days;
  before, they were deleted at once) and cleared by the hourly timer.
- Only the production queue (Solid Queue) can be read like this. In
  development the panel says that jobs run inside the web process and
  are not kept.

## Webhooks

Webhooks whose last delivery failed, or that were switched off after
too many failures (webhooks.md): organization, address, the error and
how many in a row, with a link to the organization's page. "All
webhooks deliver" when there is none.

## Also on the dashboard

The dashboard (`/admin`) shows a warning line above the tiles, like
the Google one, when something needs attention: a mailbox with an
error, failed jobs, or a webhook switched off, each with a link to the
Status page.

## Code

- `MailboxEvent` (model), `QueueStatus` (no table; reads Solid Queue's
  own tables), `Admin::StatusController` (`show`, `retry_job`,
  `discard_job`).

## Acceptance

`test/models/mailbox_event_test.rb` (every result and reason recorded,
subject cut, pruning), `test/models/queue_status_test.rb` (job names,
no arguments in them), `test/controllers/admin/status_controller_test.rb`
(the page for super administrators only, the mail rows and log, the
webhook rows, the dashboard warning, the development note for the
queue). `bin/docker-check` reads the queue through `QueueStatus` in
the production image: a taken email shows as finished with its name,
a waiting one as scheduled.

## Security Note

The page shows senders and subjects of incoming mail and error
messages, so it is for super administrators only, like the settings.
Job arguments, which hold addresses and ids, are never shown. The mail
log keeps a sender and a subject even for mail that was ignored;
it is cut to the newest 200 per organization.
