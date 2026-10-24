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
- **Own account** (`/users/edit`, the user's name in the menu bar): name,
  email and password, confirmed with the current password; the page lists
  the user's organizations. Users cannot delete their own account
  (`DELETE /users` redirects back with a message), because ticket history
  must keep its people; administrators deactivate accounts instead.
- Account pages (sign in, sign up, password reset, edit account) and
  Devise's messages are translated (`bg`, `en`).
- The legacy 2011 password pepper support from g0no was removed with the
  old migrations; `DEVISE_PEPPER` is no longer read.

## Sign-up

Controlled by `REGISTRATION_OPEN`: open by default in development and test,
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

## Security Note

Keep sign-up closed on a public host. Password reset emails need SMTP
settings, which are not configured yet (roadmap). The `.env` copied from
g0no when Stopan was created holds g0no's secrets; regenerate it for Stopan
(delete it and run `bin/setup-env`).
