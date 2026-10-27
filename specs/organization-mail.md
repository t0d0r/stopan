# Email per organization (SMTP and mailbox)

Requested by the operator on 2026-10-27: "every organization should have
its own SMTP settings and a mailbox". Decisions taken with the operator
the same day: incoming mail is fetched over IMAP (no change to any mail
server); a sender whose address has an account gets the ticket on that
account; new requesters get a magic sign-in link (public-form.md).

## Settings (admin, organization page)

Google accounts can sign in instead of passwords (mail-oauth.md).

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

- When automatic fetching is on, every few minutes (below) the app checks
  each organization with the mailbox enabled: IMAP login, select the
  folder, search `UNSEEN`, take at most 50 messages per check (oldest
  first), process each and mark it `\Seen`. A message that fails to
  process is marked `\Seen` too and its error logged, so one bad message
  does not block the queue; the organization's `imap_last_error` shows it.
- **On /admin/settings** (operator, 2026-10-27: "make it an option in
  settings"), panel "Mailboxes" (`#mailboxes`): a check box "Fetch new
  mail from the organizations' mailboxes automatically"
  (`app_settings.mailbox_polling`, default off) and "How often": every 1,
  2, 5, 10 or 15 minutes (`app_settings.mailbox_poll_seconds`, 60, 120,
  300, 600, 900; default 120). A change applies within half a minute,
  without a restart. "Check the mailbox" on an organization page fetches
  at once whatever the setting.
- The poller runs inside the web process (one Puma process, like Action
  Cable's async adapter), started only by `rails server` (never in the
  console, rake tasks or tests). It wakes every 30 seconds, reads the
  setting, and checks the mailboxes when fetching is on and the chosen
  interval has passed since its last check. `MAILBOX_POLLING=false` in
  the environment is the operator's switch to keep the poller from
  starting at all, whatever the setting. Checks never overlap. `bin/rails
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
   `-----Original Message-----`. Spaces at line ends are removed and more
   than one empty line in a row becomes one (operator, 2026-10-27). Cut
   to 20,000 characters. An empty text becomes "(no text)". Addresses
   are shown as short links (markdown.md "Plain text links").
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

### Display of mail

Operator, 2026-10-27: "the formatting of the read mail is bad ... you
must know the ticket source; if it came from a mailbox, the formatting
must suit it". A request or reply with source `email` that is not
Markdown is laid out as mail (pages, shared pages, translations and
notification emails), on top of the plain text rules (line breaks,
short links, markdown.md "Plain text links"):

- **Rules:** a line of three or more `-`, `_`, `=` or `*` (and nothing
  else) becomes a thin horizontal line.
- **Quotes:** consecutive lines starting with `>` become one quote block
  (left rule, softer ink), one `>` level removed.
- **Signature:** from a line that is exactly `-- ` or `--` (the usenet
  signature separator) to the end: smaller, softer text, set apart by a
  rule.
- **Footer:** the text after the last rule line, when that rule is in
  the second half of the message (newsletters put their "This email was
  intended for ... / Unsubscribe" there): smaller, softer text.
- Nothing is hidden or removed; the copy box copies all of it, with full
  addresses. Messages from the app and the web form keep the plain text
  layout.

### Mail details

Operator, 2026-10-27: "tickets from mail should have a section at the
start with the important things from the mail headers".

- When a mail becomes a new ticket, `tickets.mail_headers` (JSON) keeps:
  `from`, `to` and `cc` (lists), `reply_to`, `date` (ISO 8601, with the
  sender's offset), `subject` (the original, before `Re:`/`Fwd:` were
  stripped) and `message_id`. Addresses as "Name <address>" (decoded) or
  the bare address; at most 20 per list and 300 characters per value.
  Empty fields are left out. Tickets made before this have none and show
  nothing.
- On the ticket page, **staff only**, the request starts (above its
  heading, outside the in-place edit frame) with a message header in the
  manner of a mail program such as Roundcube (operator: "nicer
  formatting, like Roundcube"): the requester's avatar, the sender's name
  in bold with the address after it, the date at the right (short
  format), a line "To: ..." and "Cc: ..." (separated by a middle dot), and a "Details" disclosure
  (`<details>`) with From, To, Cc, Reply-To (only when different from
  From), the full date with the sender's UTC offset, the original
  Subject and the Message-ID. A tinted band across the top of the note;
  on phones the date goes under the sender and the details stack.
- Not on shared pages, not for requesters and not in emails: the headers
  name other recipients.
- Replies that come in by mail keep no headers yet (todo).

### HTML view

Operator, 2026-10-27: "can these tickets have nicer formatting, like
Roundcube". Mail programs show the HTML part of a mail; the text part of
a newsletter is often an afterthought.

- **Kept at intake:** for a new ticket, the mail's HTML part (or the
  whole mail when it is HTML only) is cleaned and stored in
  `tickets.mail_html`, at most 1 MB after cleaning (larger: not kept).
  The text part stays the description, as before; replies keep no HTML
  yet.
- **Cleaning** (Nokogiri, before storing): `script`, `iframe`, `frame`,
  `object`, `embed`, `applet`, `form`, `input`, `button`, `textarea`,
  `select`, `base`, `meta`, `link` and `noscript` elements are removed,
  and every `on*` attribute; links keep only `http`, `https` and
  `mailto` targets and open in a new tab with `rel="noopener noreferrer
  nofollow"`; images keep only `http`, `https` and `data:image/` sources
  (`cid:` inline images lose their source and show their alt text).
  Styles (`style` elements and attributes) stay, so the layout survives.
- **Shown in a sealed frame:** `GET /tickets/:number/mail` returns the
  cleaned HTML in a small document of its own (white page, the mail's
  styles, images at most the frame width), to anyone who may see the
  ticket (staff, the ticket's requester; 404 otherwise; never on shared
  pages). Its own headers: `Content-Security-Policy: default-src 'none';
  style-src 'unsafe-inline'; img-src data:; font-src data:;
  frame-ancestors 'self'; base-uri 'none'; form-action 'none'; sandbox
  allow-popups allow-popups-to-escape-sandbox allow-same-origin`,
  `Referrer-Policy: no-referrer`, `Cache-Control: private, no-store`. No
  script can run there, nothing outside loads, forms cannot send.
- **Remote images are blocked** by default, as in Roundcube: when the
  mail has `http(s)` images, a bar above the frame says "Remote images
  are blocked to protect your privacy" with "Show images", which
  reloads the frame with `?images=1` (then `img-src data: https: http:`).
  The choice holds for that page view only.
- **On the ticket page**, the request of such a ticket shows two small
  tabs "HTML" and "Text" above the text (HTML first). The frame
  (`sandbox="allow-popups allow-popups-to-escape-sandbox
  allow-same-origin"`, `referrerpolicy="no-referrer"`) grows to its
  content's height; the long request collapse (timeline.md) applies to
  it too. "Text" shows the description as before (mail layout, short
  links). The copy box copies the text of the view that is shown.
  Without JavaScript the frame shows at a fixed height with its own
  scroll bar and the text below it.

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
