# Authentication

Devise 5 with `database_authenticatable`, `registerable`, `recoverable`,
`rememberable`, `trackable`, `validatable` and `lockable`.

- The sign-in form has one field, "Email or username"; it matches either,
  case-insensitively (`User.find_for_database_authentication`).
- Passwords are 8 to 128 characters.
- **Lockable:** 10 failed sign-ins lock the account for 15 minutes
  (`unlock_strategy :time`, no email needed). The sign-in error does not say
  whether the account exists (`paranoid` mode).
- **Deactivated users** (`deactivated_at` set) cannot sign in
  (`active_for_authentication?` false, message "Your account has been
  deactivated. Contact your service desk administrator."), and a signed-in
  session ends on the next request.
- Sign-out is `DELETE /users/sign_out` (a `button_to` in the menu bar).
- **Magic sign-in links** for requesters (public-form.md "Magic sign-in
  links"): `GET /magic/:token` then a "Sign in" button (`POST`), one
  use, 24 hours, never for staff; the
  sign-in page has "Email me a sign-in link".
- **Own account** (`/users/edit`, the user's name in the menu bar): name,
  email and password, confirmed with the current password (except for a
  requester who has not chosen a password yet, public-form.md); the page lists
  the user's organizations. Users cannot delete their own account
  (`DELETE /users` redirects back with a message), because ticket history
  must keep its people; administrators deactivate accounts instead.
- Account pages (sign in, sign up, password reset, edit account) and
  Devise's messages are translated (`en`, `bg`, `de`). The language follows the
  user's choice, the header switch or the browser's `Accept-Language`
  (ui.md "Language"). Devise's own views and its English error
  partial are not used: form errors use the app's `form_errors` box.
- **Password reset email** (`devise/mailer/reset_password_instructions`,
  HTML and text parts, the app's mail layout): greeting with the user's
  display name, one sentence on what was asked, the "Change my password"
  link, how long the link works (`reset_password_within`, 6 hours) and
  that the password stays unchanged if the link is not used. It is written
  in the language of the request that asked for it (strings under
  `mailer.*`). It is the only email Devise sends: `password_change`,
  `email_changed` and unlock emails are off (unlock is by time). An
  unknown address sends nothing and shows the same message as a known one
  (`paranoid`).
- The legacy 2011 password pepper support from g0no was removed with the
  old migrations; `DEVISE_PEPPER` is no longer read.

## Rate limits (2026-11-12)

Devise's lock protects one account; these limits stop one client from
trying many accounts or sending many reset emails.

- **Sign-in:** 20 attempts (`POST /users/sign_in`) per 5 minutes per
  client address. Over it the attempt is not looked at: the browser goes
  back to the sign-in page with "Too many sign-in attempts. Please try
  again in a few minutes.", nobody is signed in, the account's failed
  attempts do not grow, and a right password is answered like a wrong
  one. The sign-in page itself (`GET`) is never limited.
- **Password reset requests** (`POST /users/password`): 5 per 10 minutes
  per client address, and 5 per 10 minutes per address asked for
  (trimmed, lower case), like the magic links (public-form.md). Over it
  no email is sent and the forgot-password page shows "Too many
  requests. Please try again in a few minutes.".
- The sign-in limit runs before every other callback
  (`Users::SessionsController`, `prepend_before_action`), because
  Devise's first callback already checks the password. Its message
  follows the language cookie or the browser, since no user is known
  yet. The reset limit uses Rails `rate_limit`
  (`Users::PasswordsController`).
- Counters live in the memory of the one Puma process (as for the other
  limits), so a restart clears them.
- The limit is above the 10 failed attempts that lock an account, so a
  person who mistypes locks only their own account, for 15 minutes.
- **Client address:** the limits need `request.remote_ip` to be the
  visitor's. Production without `TRUSTED_PROXIES` sees the server's own
  address for everyone (public-form.md "Abuse protection"), so there
  the limits are shared by all visitors: safe against guessing, but one
  client can then keep everyone from signing in for a few minutes at a
  time. Set `TRUSTED_PROXIES` in production (deploy.md).

`test/controllers/sign_in_rate_limit_test.rb`: the 21st attempt is
refused even with the right password and signs nobody in; the refusal
is in the visitor's language and counts no failed attempt; another
address still signs in; the page is not limited; reset requests are
limited per client address and per address asked for, and send no
email over the limit.

## Sign-up

The form asks for name (optional), email and password. Controlled by
`REGISTRATION_OPEN`: open by default in development and test,
closed by default in production. A self-registered user is a requester
without organizations, so they can sign in but cannot open tickets until an
administrator adds them to an organization. When closed, the sign-up link is
hidden and `GET /users/sign_up` and `POST /users` redirect to sign-in with
"Sign-up is closed. Ask an administrator for an account."

## Admin user

`db/seeds.rb` creates the user `ADMIN_USERNAME` (default `admin`) with
`ADMIN_EMAIL`, `ADMIN_PASSWORD` and role `admin` when no user with that
username exists (case-insensitive). For an existing user with that username
it only sets role `admin` if needed; email and password are never changed.
Without `ADMIN_EMAIL` or `ADMIN_PASSWORD` it prints a message and does
nothing. The password is never printed.

`bin/setup-env` creates `.env` from `.env.example` (mode 600) when it is
missing and fills only empty values: `SECRET_KEY_BASE`, `ADMIN_EMAIL`,
`ADMIN_USERNAME`, `ADMIN_PASSWORD`. `make run` runs it, loads `.env`, seeds
and starts the server.

## Demo data (development only)

`make demo` (`bin/rails stopan:demo`) creates two example organizations, an
agent, three requesters and a handful of tickets with replies, notes and
status changes, all with `example.com` addresses. It needs `DEMO_PASSWORD`
in the environment (used for every demo user, never printed) and refuses to
run in production. Running it again does nothing if the demo data exists.
The development container (`make docker-dev`, docker.md) runs it on every
start with `DEMO_PASSWORD` from `.env`, which `bin/setup-env` generates.

| user | role | organization |
|------|------|--------------|
| Maria Ivanova, maria.agent@example.com | agent | - |
| Petar Georgiev, petar.agent@example.com | agent | - |
| Anna Petrova, anna@example.com | requester | Acme Bakery |
| Boris Dimitrov, boris@example.com | requester | Acme Bakery |
| Chris Taylor, chris@example.com | requester | Globex Logistics |

## Acceptance

`test/integration/account_pages_bulgarian_test.rb`: with `Accept-Language:
bg` the sign-in, sign-up, forgot-password, reset-password and own-account
pages contain no Latin words except the brand and user data, sign-up
errors are Bulgarian, and the reset email (subject, HTML and text) follows
the request language. `test/i18n/locales_test.rb` checks that `ui`, `flash`
and `mailer` keys match in both languages.

## Security Note

Keep sign-up closed on a public host. Password reset emails need SMTP
(`SMTP_ADDRESS` and friends, notifications.md); without it no email is sent. The `.env` copied from
g0no when Stopan was created holds g0no's secrets; regenerate it for Stopan
(delete it and run `bin/setup-env`).
