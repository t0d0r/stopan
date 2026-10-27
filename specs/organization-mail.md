# Email per organization (SMTP and mailbox)

Requested by the operator on 2026-10-27: "every organization should have
its own SMTP settings and a mailbox". Decisions taken with the operator
the same day: incoming mail is fetched over IMAP (no change to any mail
server); a sender whose address has an account gets the ticket on that
account; new requesters get a magic sign-in link (public-form.md).

## Settings (admin, organization page)

A "Mail" panel on the organization edit page, two parts, each with an
"enabled" switch. Nothing is sent or fetched for an organization until
its part is enabled.

| part | fields |
|------|--------|
| Outgoing (SMTP) | `smtp_enabled`, `smtp_address` (host), `smtp_port` (default 587), `smtp_security` (`starttls` default, `tls` for implicit TLS on 465, `none`), `smtp_username`, `smtp_password`, `mail_from` (address and optional name, for example `Acme Support <support@acme.example>`) |
| Mailbox (IMAP) | `imap_enabled`, `imap_address` (host), `imap_port` (default 993), `imap_ssl` (default on), `imap_username`, `imap_password`, `imap_folder` (default `INBOX`), `mailbox_address` (the address customers write to; also the Reply-To of outgoing mail) |

- Passwords are stored encrypted (Active Record encryption,
  `encrypts :smtp_password, :imap_password`). The keys are derived from
  `SECRET_KEY_BASE` (`config/initializers/encryption.rb`), so no new
  secret is needed; changing `SECRET_KEY_BASE` makes the stored
  passwords unreadable, and they must be entered again.
- Password fields are write-only: the form never shows the stored value
  ("A password is stored" hint); a blank field keeps it, a "Remove the
  stored password" check box clears it.
- Validation when a part is enabled: host present, port 1-65535,
  addresses valid (`mail_from` parsed with `Mail::Address`); the hosts
  must not be loopback, private or link-local addresses when given as IP
  literals (no reaching services inside the server).
- "Send a test email" (to the signed-in admin) and "Check the mailbox"
  (logs in, selects the folder, counts unseen messages, logs out) buttons
  report success or the error message in a notice/alert. Errors never
  include the password.
- The organization page shows, for the mailbox, the last check time, the
  number of messages taken in, and the last error.
- Only administrators see or change any of this (admin.md); the
  settings never appear on other pages, in emails or logs
  (`filter_parameters` covers `password`).

## Outgoing mail

All mail about a ticket goes through its organization's SMTP when that is
enabled, else through the global `SMTP_*` settings (notifications.md):

- ticket notifications (TicketMailer), the confirmation with the magic
  link after a public request (public-form.md), mailbox auto-answers;
- From: the organization's `mail_from` (else `MAILER_SENDER`);
  Reply-To: the organization's `mailbox_address` when the mailbox is
  enabled, so replies by email come back as replies on the ticket;
- the subject keeps `[Stopan #1001]` and the `References` header, which
  the mailbox uses to match replies.

Mail not tied to one ticket (password reset, a sign-in link asked for on
the sign-in page) uses the global settings, or the organization's when
the user belongs to exactly one organization with SMTP enabled.

Delivery is `ActionMailer` with per-message `delivery_method_options`
(Rails' supported way to switch SMTP settings per email), in the
in-process job queue as today.

## Mailbox (incoming mail)

### Fetching

- Every `MAILBOX_POLL_SECONDS` (default 120) the app checks each
  organization with the mailbox enabled: IMAP login, select the folder,
  search `UNSEEN`, take at most 50 messages per check (oldest first),
  process each and mark it `\Seen`. A message that fails to process is
  marked `\Seen` too and its error logged, so one bad message does not
  block the queue; the organization's `imap_last_error` shows it.
- The poller runs inside the web process (one Puma process, like Action
  Cable's async adapter), started only by `rails server` and only when
  `MAILBOX_POLLING=true` (production sets it; development and tests do
  not). Checks of one organization never overlap. `bin/rails
  stopan:mailboxes:check` runs one check of every mailbox by hand.
- Connections use TLS with certificate verification when `imap_ssl` is
  on; a timeout of 30 seconds per connection.

### Processing a message

1. **Skip** automatic mail, to avoid loops with auto-responders: an
   `Auto-Submitted` header other than `no`, `Precedence` `bulk`, `junk`
   or `list`, `X-Autoreply`, `X-Autorespond`, a `List-Id`, an empty or
   `MAILER-DAEMON` sender, and mail from the organization's own
   `mail_from` or `mailbox_address`.
2. **Sender:** the `From` address. Same rules as the public form
   (public-form.md "Who the request belongs to"): a requester with that
   email (case-insensitive) is used and added to the organization when
   not a member; an unknown address gets a new requester account (name
   from the `From` display name, else the part before `@`) and the
   membership; a staff address may only reply to an existing ticket (as
   a public reply, and an agent only on a ticket of their own
   organizations, roles.md); deactivated users and staff starting a new
   ticket are skipped and logged.
3. **Reply or new ticket:** a reply when the subject has `[Stopan
   #<number>]` or `In-Reply-To`/`References` has `<ticket-<number>@host>`,
   the ticket belongs to this organization, and the sender is its
   requester or staff. Then the text becomes a public reply by the sender
   (with the usual automatic status changes, timeline.md: a requester's
   reply to a done ticket reopens it). Otherwise a new ticket in the
   organization: subject from the mail subject (stripped of `Re:`/`Fwd:`,
   "(no subject)" when empty, cut to 200 characters), description from
   the text, `source` "email".
4. **Text:** the `text/plain` part, else the HTML part converted to text
   (tags stripped, line breaks kept). For replies, quoted text is cut off
   at the first line that starts with `>`, or at a line like "On ...
   wrote:" / "На ... написа:" followed by quotes, or at
   `-----Original Message-----`. Cut to 20,000 characters. An empty text
   becomes "(no text)".
5. **Files:** attachments with an allowed type and size (attachments.md)
   are attached, at most 5; others are skipped and a line "Some
   attachments were not accepted: <names>" is added to the text. Inline
   images that are only signatures (under 10 KB) are skipped silently.
6. Notifications follow notifications.md as for any reply or new ticket;
   the sender is the actor, so they are not emailed about their own mail.
   A new requester also gets the confirmation with a magic link
   (public-form.md), through the organization's SMTP.

Tickets keep where they came from: `tickets.source` (`app`, `web_form`,
`email`) and `comments.source` (`app`, `email`); the timeline shows "by
email" / "through the web form" next to the entry.

## Not in this phase

OAuth2 sign-in to mail providers (Google, Microsoft 365), POP3, moving
processed mail to another folder, spam scoring, per-organization
templates and signatures. Recorded in roadmap.md.

## Acceptance

`test/models/organization_mail_test.rb` (validation, encryption,
private hosts refused, write-only passwords),
`test/mailers/ticket_mailer_test.rb` (per-organization SMTP options,
From, Reply-To, fallback to the global settings),
`test/models/mailbox_message_test.rb` (new ticket, reply by subject and
by References, quotes cut, auto-replies and loops skipped, unknown and
known senders, staff replies, done tickets reopened, attachments, limits) and
`test/models/mailbox_check_test.rb` (IMAP with a fake server: unseen
only, marked seen, errors recorded, at most 50).

## Security Note

Mail credentials of every organization are kept in the database,
encrypted with keys derived from `SECRET_KEY_BASE`: whoever has both the
database and the environment file can read them, so back both up and
store them as carefully as the passwords themselves; prefer app-specific
mailbox passwords. Incoming mail is untrusted: it is stored as plain text
(HTML is converted, never rendered), attachments pass the same type and
size checks as uploads, and the sender address can be forged, exactly as
with any email-based service desk: anyone can add a reply to a ticket by
writing from its requester's address and quoting its number. Staff should
treat email replies like phone calls from an unverified number. The
private-address check stops the settings from being used to probe the
server's internal network.
