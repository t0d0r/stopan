# Google and Microsoft accounts for organization mail (plan)

Status: Google built (phases 2 and 3), live check pending; Microsoft
planned. Operator, 2026-10-27: "plan support for
Google and Microsoft accounts for the mailboxes", then "Google Workspace
first, Internal, outgoing also through the account".

## Decisions taken (2026-10-27)

- **Google Workspace first.** Microsoft follows the same design later;
  its parts below stay as the plan for it.
- **Google app type "Internal":** only mailboxes of the operator's own
  Workspace can connect, so Google's verification and security
  assessment are not needed. Customers' own Google mailboxes are out of
  scope until that changes.
- **Outgoing mail goes through the connected account too** (SMTP with
  XOAUTH2 at `smtp.gmail.com`), so it is sent from the organization's
  domain and passes its SPF and DKIM.
- Library check done locally (no network): `net-smtp` 0.5.2 ships
  `auth_xoauth2` (`authentication: :xoauth2`), `mail` 2.9.1 passes the
  `authentication` setting through to it, and `net-imap` 0.6.8 ships
  `XOAUTH2Authenticator`. The live check against a Workspace mailbox is
  still to do (phase 1).
- Still open: who registers the Google Cloud OAuth client (Internal
  consent screen, redirect URI below) and which Workspace mailbox serves
  for the live check.
- **Personal Gmail** (operator asked, 2026-10-27): works with the same
  code, but a personal Google account can only make an "External" OAuth
  client. In "Testing" status (own address added as a test user, no
  verification) Google's refresh tokens last 7 days, so the mailbox must
  be reconnected weekly; fine for trying it out. For lasting use of a
  personal Gmail, an app password (2-Step Verification on) in the
  existing password fields needs no OAuth at all.

## As built (Google)

- One sign-in choice per organization, `organizations.mail_auth`
  (`password`, `google`), for both parts, since outgoing mail goes
  through the account too (instead of the per-part `smtp_auth` and
  `imap_auth` below).
- `/admin/settings`, panel "Google": the redirect URI to copy
  (`admin_mail_oauth_callback_url`), Client ID, and the Client secret,
  encrypted and write-only (blank keeps it, a check box removes it).
- Organization page, Mail facts: "Sign-in: Username and password" or
  "Google account support@...", with "Needs reconnecting" when the
  refresh token was refused. Buttons: "Connect with Google" (or
  "Reconnect with Google") when a client is set, a GET link with Turbo
  off, because a form may not redirect to Google under the CSP
  (`form-action 'self'`); "Disconnect Google" (with confirmation). The
  edit form hides the username and password fields while a Google
  account is connected and says so.
- `GET /admin/organizations/:id/mail_oauth/google` (start),
  `GET /admin/mail_oauth/callback`, `DELETE
  /admin/organizations/:id/mail_oauth`; administrators only. The state,
  PKCE verifier, organization and expiry (10 minutes) live in the
  session and are deleted when the callback arrives, whatever its
  outcome, so a state works once.
- Connecting stores the account in `mail_connections` and sets the
  organization to `mail_auth: google`, both parts enabled,
  `smtp.gmail.com:587` STARTTLS and `imap.gmail.com:993` SSL with the
  account as username, clears the stored passwords, and keeps a From and
  mailbox address already set (else the account's address).
  Disconnecting revokes the refresh token at Google (best effort),
  deletes the connection, and sets `mail_auth: password` with both parts
  off.
- `GoogleOauth`: authorize URL (`access_type=offline`,
  `prompt=consent`, S256), code exchange, refresh, revoke; reads the ID
  token from the token response (TLS, no signature check, OpenID
  Connect Core 3.1.3.7) and requires `aud` = the client, a Google
  `iss`, and `email_verified`; `invalid_grant` raises InvalidGrant.
- `MailConnection#access_token` caches tokens in memory until a minute
  before expiry; InvalidGrant marks the connection `needs_reconnect`.
  `smtp_ready?`/`imap_ready?` are false then: the poller skips the
  mailbox and mail goes through the global SMTP. SMTP uses
  `authentication: :xoauth2`, IMAP `authenticate("XOAUTH2", ...)`.

Today an organization's mail (organization-mail.md) signs in to SMTP and
IMAP with a username and password. Google (Gmail, Google Workspace) and
Microsoft (Microsoft 365, Outlook.com) no longer accept passwords for
IMAP and SMTP, or accept them only as app passwords that tenants often
forbid. Both require OAuth 2.0 and the SASL mechanism XOAUTH2. This plan
adds that as a third way to sign in, next to the password.

## Decisions proposed

1. **Keep IMAP and SMTP, sign in with XOAUTH2**, instead of moving to the
   Gmail API or Microsoft Graph. The mailbox poller, the processing of
   messages (organization-mail.md "Processing a message"), the outgoing
   routing and the tests stay as they are; only the login step changes.
   `net-imap` 0.6 has an XOAUTH2 authenticator; `net-smtp` 0.5 and the
   `mail` gem take `authentication: :xoauth2` (to confirm in phase 1).
2. **Delegated sign-in with a refresh token** (OAuth authorization code
   flow with PKCE and `state`): an administrator clicks "Connect with
   Google" or "Connect with Microsoft" on the organization's Mail panel,
   signs in as the mailbox (for example `support@acme.example`) at the
   provider and agrees; Stopan stores the refresh token and the mailbox
   address. No mailbox password is ever stored for these.
3. **One OAuth app per provider for the whole installation**, registered
   by the operator: client id and client secret entered on
   `/admin/settings` ("Mail accounts" panel), stored encrypted and
   write-only like the DeepL key (translation.md). Microsoft also takes
   the tenant (`common`, `organizations` or a tenant id). The redirect URI
   shown there is `https://<APP_HOST>/admin/mail_oauth/callback`.
4. Each organization chooses per part (outgoing, mailbox) how to sign
   in: "Password" (as today), "Google" or "Microsoft". Usually both parts
   use the same connected account.

## Provider details

| | Google | Microsoft |
|---|---|---|
| App registration | Google Cloud project, OAuth consent screen, "Web application" client | Entra ID app registration, "Web" platform |
| Scopes | `https://mail.google.com/` (IMAP and SMTP need this full scope) plus `openid email` | `https://outlook.office.com/IMAP.AccessAsUser.All`, `https://outlook.office.com/SMTP.Send`, `offline_access`, `openid email` |
| Endpoints | `accounts.google.com/o/oauth2/v2/auth`, `oauth2.googleapis.com/token` | `login.microsoftonline.com/<tenant>/oauth2/v2.0/authorize` and `/token` |
| IMAP / SMTP hosts | `imap.gmail.com:993`, `smtp.gmail.com:587` | `outlook.office365.com:993`, `smtp.office365.com:587` |
| Refresh token | `access_type=offline&prompt=consent` | `offline_access`; rotates on each refresh, store the new one |
| Caveats | `https://mail.google.com/` is a restricted scope: an "External" app needs Google's verification and a security assessment; an "Internal" app in the operator's own Workspace does not, but then only that Workspace's mailboxes can connect. Testing mode tokens expire after 7 days. | The tenant admin may have to consent once; "Authenticated SMTP" must be enabled for the mailbox in Exchange; IMAP must be enabled. |

## Behaviour

- **Connect:** `GET /admin/organizations/:id/mail_oauth/:provider`
  redirects to the provider with `state` (signed, bound to the session,
  the organization and the provider, 10 minutes) and a PKCE challenge.
  The callback checks `state`, exchanges the code, reads the account's
  email from the ID token, stores it and the refresh token, fills the
  host, port and security of the chosen parts with the provider's values,
  and returns to the Mail panel with "Connected as support@acme.example".
- **Use:** before an IMAP check or an SMTP delivery, take a cached access
  token (in memory, until a minute before it expires) or refresh it; then
  `imap.authenticate("XOAUTH2", email, token)` or SMTP with
  `authentication: :xoauth2`. A refreshed Microsoft refresh token
  replaces the stored one.
- **Failure:** `invalid_grant` (revoked, password changed, consent
  removed) marks the connection "needs reconnecting", stops polling that
  mailbox, shows a warning on the Mail panel and the admin dashboard, and
  falls back for outgoing mail to the system SMTP, as for a broken
  password today (organization-mail.md "Outgoing mail"). Other errors
  are retried at the next poll and logged without tokens.
- **Disconnect:** a button that revokes the token at the provider (best
  effort) and deletes it; the part goes back to "not configured".
- The existing "Send test email" and "Check mailbox now" buttons work
  the same for connected accounts.

## Data model

`organizations`: `smtp_auth` and `imap_auth` (`password` default,
`google`, `microsoft`), and a new table `mail_connections`
(`organization_id`, `provider`, `email`, `refresh_token` encrypted,
`status` `connected`/`needs_reconnect`, `connected_at`, `last_error`,
timestamps), one per organization and provider. `app_settings`:
`google_client_id`, `google_client_secret` (encrypted),
`microsoft_client_id`, `microsoft_client_secret` (encrypted),
`microsoft_tenant`.

## Phases

1. **Spike:** confirm XOAUTH2 with `net-imap` 0.6, `net-smtp` 0.5 and
   `mail` 2.9 against a test Google Workspace mailbox and a test
   Microsoft 365 mailbox (needs the operator's test accounts and app
   registrations). Write down anything that differs from this plan.
2. **Settings and connect flow:** the OAuth app fields on
   /admin/settings, the connect, callback and disconnect routes, the
   `mail_connections` table, the Mail panel choices and status.
3. **Use the tokens:** token refresh and caching, XOAUTH2 in
   `MailboxCheck` and in the organization SMTP settings, failure
   handling and the dashboard warning.
4. **Production:** the operator registers the apps with the production
   redirect URI, enters the credentials, connects the first mailbox;
   deploy notes in deploy.md.

## Tests

A fake OAuth provider (authorize, token, revoke) and the existing fake
IMAP class: connect stores an encrypted refresh token and the email;
`state` mismatch, expiry and replay are refused; a refreshed Microsoft
token replaces the old one; `invalid_grant` marks the connection and
stops polling; XOAUTH2 is used for IMAP and SMTP when chosen and the
password otherwise; only administrators reach any of it; tokens never
appear in logs or pages.

## Open questions for the operator

- Who registers the Google Cloud OAuth client and gives a Workspace
  mailbox for the live check? (The other questions were answered, see
  "Decisions taken".)
- Microsoft: which tenant, and who registers the Entra app, when it is
  its turn.

## Security Note

A refresh token is as strong as the mailbox password: it is stored
encrypted (Active Record encryption, keys from `SECRET_KEY_BASE`),
never shown, never logged, sent only to the provider's token endpoint,
and revoked on disconnect. The scopes are the smallest that IMAP and
SMTP accept (Google has no narrower one for IMAP). `state` and PKCE stop
a forged or replayed callback from attaching a stranger's mailbox; only
administrators can connect. Database backups contain the encrypted
tokens and must be kept as carefully as the database.
