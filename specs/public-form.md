# Public request form per organization

Requested by the operator on 2026-10-27: "each organization should have
its own new ticket page where people can post without an account; posting
creates a requester account". Decisions taken with the operator the same
day: the page is off until an administrator turns it on; an address that
already has an account gets the ticket on that account; the requester
gets in with a magic sign-in link.

## Page

- `GET /support/:slug` shows the form, `POST /support/:slug` creates the
  request. `slug` is the organization's URL name (`organizations.slug`,
  lower-case letters, digits and dashes, 2-60 characters, unique; filled
  from the name when the organization is created, editable by admins).
- Off by default: `organizations.public_form` (boolean, default false),
  switched in the organization's edit form. A switched-off or unknown
  slug renders "This page is not available" with 404, the same for both.
- No sign-in. A signed-in user who opens the page is sent to the normal
  new ticket form (tickets.md).
- The page is a yellow sticky like the new ticket form, headed with the
  organization's name ("Contact Acme Bakery support"), and an optional
  intro text (`organizations.public_intro`, plain text, at most 1,000
  characters, set by admins).
- Fields: name (required, at most 100), email (required, valid), subject
  (required, at most 200), description (required, at most 20,000), the
  "Markdown" check box (markdown.md). No files in this phase (an
  anonymous form must not fill the storage; files can be added to the
  ticket after signing in, or sent by email when the mailbox is on).
- The page's address is easy to copy (operator, 2026-10-27): the
  organization page and the "Public request page" part of its edit form
  show it in a read-only field with "Copy link" and "Open" (a new tab);
  the edit form shows it for the saved URL name, with a note when the
  page is off; the organizations list has a one-click copy icon next to
  each organization whose page is on. Copying shows "Copied" for 2
  seconds.

## Who the request belongs to

The email address is the identity, as in email-based service desks (the
same rules apply to the mailbox, organization-mail.md):

| the address belongs to | result |
|------------------------|--------|
| nobody | a new requester: name and email from the form, the page's language (for their emails), a random password nobody knows, a membership in the organization |
| an active requester | the ticket is theirs; they become a member of the organization when they were not |
| a deactivated user, an agent or an administrator | nothing is created; the page answers as if it had worked (below) and the attempt is logged; staff must sign in to open tickets |

- The answer page is the same in every case ("Thank you. We received
  your request and sent a confirmation to <email>."), so the form does not
  reveal which addresses have accounts. The ticket number is shown only
  in the email.
- The ticket: requester as above, the organization, status `new`,
  priority `normal`, `source` "web_form", actor the requester; the usual
  `created` event and staff notifications (notifications.md).
- A confirmation email goes to the address (through the organization's
  SMTP, organization-mail.md): the ticket number and subject, their text,
  and a magic sign-in link that opens the ticket. For a staff or
  deactivated address no email is sent.

## Magic sign-in links

- A link `GET /magic/:token` shows a small page "Sign in as <name>"
  with one "Sign in" button; `POST /magic/:token` signs the requester in
  and opens a page (the ticket from the confirmation, else My tickets).
  The button step exists because mail scanners and link previews (for
  example Outlook's Safe Links) open links before the person does, and a
  plain GET would use up the one-time link. The token is
  `User#generate_token_for(:magic_sign_in)`: signed, expiring after 24
  hours, and bound to the user's `current_sign_in_at`, so it works once
  (signing in changes that value) and stops working after any other
  sign-in. The return page is a ticket number checked against
  `Ticket.visible_to` after sign-in.
- Only active requesters can use a link; for staff, deactivated or
  locked users and for bad or used tokens the page says "This sign-in link
  is not valid any more" with a form to ask for a new one.
- The sign-in page has "Email me a sign-in link" (email only): it sends a
  link when the address belongs to an active requester and always
  answers "If an account exists for this address, we sent a link", so it
  reveals nothing. Rate limited like password resets (5 per 10 minutes
  per address and per IP).
- Requesters created by the form or the mailbox have a random password
  they do not know (`users.password_chosen` false; true for everyone
  else). Their account page lets them choose a password without the
  current one; once chosen, it is required as usual (auth.md). Until
  then magic links are their way in.

## Abuse protection

- Rate limit per IP: 5 requests per 10 minutes and 20 per day for the
  form (Rails `rate_limit`, cache store); over it the form shows "Too many
  requests, please try again later" with 429.
- A honeypot field (visually hidden, `tabindex=-1`, `autocomplete=off`)
  that people leave empty; when filled, the page answers as if it had
  worked and creates nothing.
- A form older than 24 hours or younger than 3 seconds (a signed
  timestamp in the form) is refused the same way, against replayed and
  scripted posts.
- The client IP must be the visitor's: production sits behind Apache,
  pasta and Thruster, and the app sees the server's own address
  (checked 2026-10-27). `TRUSTED_PROXIES` (comma-separated addresses or
  ranges) adds the proxy addresses to the ones Rails trusts, so
  `request.remote_ip` comes from `X-Forwarded-For`; production sets it to
  the server's address (deploy.md). Without it the per-IP limit is shared
  by everyone, which is safe but strict.

## Acceptance

`test/controllers/public_requests_controller_test.rb` (off and unknown
slugs 404, new and known requesters, membership added, staff and
deactivated addresses create nothing with the same answer, honeypot,
timing, rate limit, signed-in users redirected, confirmation email with a
link through the organization's SMTP) and
`test/controllers/magic_links_controller_test.rb` (sign-in once, expiry,
staff refused, return page checked, "email me a link" answers the same
for unknown addresses, rate limit).

## Security Note

The form lets anyone create a requester account and a ticket for an
organization once its page is on: keep it off for organizations that do
not need it, watch for spam, and keep the rate limits. Because the email
address is the identity, anyone can open a ticket in someone else's name;
they cannot read it, since only the address owner gets the sign-in link.
Magic links are as strong as the mailbox they are sent to; they expire
after 24 hours, work once and never sign in staff.
