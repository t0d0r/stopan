# Production deployment

Operator, 2026-10-25: deploy Stopan to the operator's Debian server under
the public host name `stopan.linuxfan.org`, completely independent of
g0no. The website is registered only through the ISPConfig Remote API
(`sites_web_domain_add`); no direct writes to ISPConfig tables and no
hand-written Apache vhost. The app runs as rootless Podman under its own
system user on a loopback-only port, behind the ISPConfig-managed Apache
vhost, which also obtains the Let's Encrypt certificate.

## Status

**Deployed 2026-10-26, revision e553a58; updated 2026-10-27 to revision
fa69269** (operator: "deploy to production"). https://stopan.linuxfan.org
is served by ISPConfig site 25 (`web25`) proxying to the rootless
container of the `stopan` user. See "Deployed resources", "Verified" and
"Update 2026-10-27".
The deployment waited on ISPConfig Remote API access on 2026-10-25/26
("Remote API access history").

## Layout

| part | where |
|------|-------|
| website | ISPConfig site `stopan.linuxfan.org`, client 1 (the same client and settings as the g0no site), created with `sites_web_domain_add` from `deploy/ispconfig-site.json`: no PHP, SSL with Let's Encrypt, rewrite HTTP to HTTPS, PageSpeed off, proxy in the site's "Apache directives" field |
| proxy | the site's Apache directives (`deploy/ispconfig-site.json`): `ProxyPass / http://127.0.0.1:3183/ retry=0 upgrade=websocket`, `ProxyPreserveHost On`, `X-Forwarded-Proto https`, ACME challenge path excluded, and a ModSecurity exclusion for the session cookie (below). They are stored in the ISPConfig site record, so a panel resync regenerates them |
| system user | `stopan` (system account, no login shell, home `/srv/stopan`, own subuid/subgid range, lingering so its services run without a login) |
| container | rootless Podman as `stopan`, from the quadlet `deploy/stopan.container`, installed as `~stopan/.config/containers/systemd/stopan.container`; systemd user service `stopan.service`, `Restart=always`, `WantedBy=default.target` |
| image | `localhost/stopan:latest` (also tagged with the git revision), built on the server from `Dockerfile` |
| data | `~stopan/storage` -> `/rails/storage` (SQLite databases and uploads). SQLite is the application's only database (overview.md); no MySQL database is created |
| settings | `~stopan/stopan.env`, mode 600, owner `stopan`; never in git |
| network | the container publishes only `127.0.0.1:3183`; Apache on the host is the only way in |

Port 3183: on 2026-10-25 the loopback app ports in use were 3181 and 3182
(g0no). 3183 must be proved free again immediately before the first start
(setup step 4); `bin/deploy` refuses to start when the port is held by
anything other than an active `stopan.service`.

The container runs with `no-new-privileges` and all capabilities dropped,
like g0no's; the sysctl `net.ipv4.ip_unprivileged_port_start=80`, in the
container's own network namespace only, lets the image's user listen on
port 80. A process that escapes it is the unprivileged user `stopan`,
which cannot read g0no's or the operator's files.

Live updates use Action Cable over a WebSocket on `/cable`
(notifications.md, timeline.md, queues.md, admin.md, sharing.md). Since
2026-10-27 the proxy line carries `upgrade=websocket` (Apache 2.4.47+;
the server runs 2.4.69, and `mod_proxy_http` handles the upgrade, so
`mod_proxy_wstunnel` is not needed). Thruster passes WebSockets through.
Without the upgrade, pages still work and update on load.

## Settings (`~stopan/stopan.env`)

Generated on the server with umask 077 and never copied off it:
`SECRET_KEY_BASE` (`openssl rand -hex 64`) and `ADMIN_PASSWORD`
(`openssl rand -base64 24`). `APP_HOST=stopan.linuxfan.org`,
`MAILER_SENDER=no-reply@stopan.linuxfan.org`, `ADMIN_USERNAME=admin`,
`ADMIN_EMAIL=admin@stopan.linuxfan.org` (no address was given; change it
at the account page), `RAILS_FORCE_SSL=true`,
`RAILS_ASSUME_SSL=true`, `REGISTRATION_OPEN=false` (docker.md, auth.md).
For the public forms and mailboxes (public-form.md,
organization-mail.md) production also needs `TRUSTED_PROXIES=<the
server's own address>` (Apache reaches the container through pasta,
which shows the server's address to the app) and `MAILBOX_POLLING=true`;
both are set by the operator in `stopan.env` when the features are used.
The admin password is handed to the operator on the server only, in
`/root/stopan/admin-password.txt` (root, mode 600); delete it after the
first sign-in and password change. It is never printed in a terminal log.

## ISPConfig Remote API

`bin/ispconfig-remote <method> [<json file>]` runs on the server as root.
It reads `ISPC_REMOTE_USER` and `ISPC_REMOTE_PASSWORD` from
`/root/.config/stopan/ispconfig-remote.env` (root, mode 600; another path
with `ISPC_REMOTE_ENV`), logs in to `https://127.0.0.1:8443/remote/json.php`,
calls the method with the JSON arguments plus the session, logs out and
prints the response. The panel certificate is self-signed, so the script
pins the public key of the certificate file Apache serves for the panel
instead of trusting any certificate. Credentials pass through the
environment and stdin only, never through command arguments.

The remote user needs the function group "Sites Domain functions"
(`sites_web_domain_get`, `_add`, `_update`, `_delete`), and is limited to
access from `127.0.0.1`. The user `stopan_deploy` exists with exactly
that (created in the panel 2026-10-26, datalog 618).

Bodies for `curl --data-binary @-` are built with `jq -j`: `jq -r` adds
a trailing newline, which becomes part of the last form value. The first
run of `bin/ispconfig-create-remote-user` had that bug, so the stored
function list ends in a newline and `sites_web_domain_set_status` (the
last entry) does not match; re-save the remote user in the panel to fix
it. The other four functions work.

`sites_web_domain_add` validates the PHP-FPM fields even for `php=no`:
`pm_process_idle_timeout` and `pm_max_requests` are required (values
copied from the g0no record).

Scripts and the site JSON are kept on the server in `/root/stopan`
(root, 700).

## Remote API access history (2026-10-25/26)

- The ISPConfig `remote_user` table is empty: no Remote API account exists.
- No ISPConfig panel credentials or authenticated session were provided to
  the deploying agent, so it cannot create a remote user through the panel
  (System -> Remote Users).
- Not used, because they are not supported or would alter existing
  accounts: inserting a `remote_user` row with MySQL; inserting
  `web_domain` rows; a hand-written vhost; `ispc user set-password admin`
  (it would change the operator's panel password).

This blocked the deployment until 2026-10-26. The options offered were:

1. creates the remote user in the ISPConfig panel (System -> Remote Users ->
   Add): a new username, a generated password, "Remote Access" enabled,
   "Remote Access IPs" `127.0.0.1`, function group "Sites Domain
   functions"; then writes the file on the server as root:

   ```sh
   install -d -m 700 /root/.config/stopan
   install -m 600 /dev/null /root/.config/stopan/ispconfig-remote.env
   # edit it to contain two lines:
   # ISPC_REMOTE_USER=<username>
   # ISPC_REMOTE_PASSWORD=<password>
   ```

   and tells the agent the file is in place (not the password); or
   runs `sudo bin/ispconfig-create-remote-user` on the server, which fills
   the same panel form with the admin login typed at its prompt and the
   values from that file, then checks the API login; or
2. gives the agent an authenticated panel session or panel credentials
   through a channel that does not end up in a log, and lets it create the
   remote user as in 1.

## One-time setup (after the blocker is lifted)

As root on the server unless noted:

1. Re-check: DNS of `stopan.linuxfan.org` resolves to the server; no
   `web_domain` row and no vhost for it exists; the server has capacity.
2. `useradd --system --user-group --create-home --home-dir /srv/stopan --shell /usr/sbin/nologin stopan`,
   `chmod 750 /srv/stopan`,
   `usermod --add-subuids <free range> --add-subgids <free range> stopan`
   (65536 ids not overlapping any range in `/etc/subuid` and `/etc/subgid`;
   used: 2100000-2165535),
   `loginctl enable-linger stopan`.
3. As `stopan` (`runuser -l stopan -s /bin/bash`), umask 077: create
   `~/storage`, `~/.config/containers/systemd`, `~/stopan.env` (Settings);
   install `deploy/stopan.container` into `~/.config/containers/systemd/`.
4. Prove `ss -Htln 'sport = :3183'` is empty, then `DEPLOY_HOST=<ssh host> make deploy`
   from the workstation: builds, starts `stopan.service`, waits for `/up`
   on `127.0.0.1:3183`. The entrypoint migrates and seeds the database.
5. Copy `bin/ispconfig-remote` and `deploy/ispconfig-site.json` to the server
   and run `bin/ispconfig-remote sites_web_domain_add deploy/ispconfig-site.json`.
   It prints the new `domain_id`: 25.
6. Wait for the ISPConfig server cron (one minute) to write the vhost
   (`/etc/apache2/sites-enabled/100-stopan.linuxfan.org.vhost`) and to
   obtain the certificate (certbot, webroot of the ISPConfig ACME alias,
   `/etc/letsencrypt/live/stopan.linuxfan.org_ecc/`); it took about one
   minute; `sites_web_domain_get` with `primary_id` shows
   the stored record. If Let's Encrypt fails, ISPConfig turns SSL off in
   the record; fix the cause and set it again with `sites_web_domain_update`.

## Deploy (`make deploy`)

`DEPLOY_HOST=<ssh host> make deploy` runs `bin/deploy`: `git archive HEAD`
into `~stopan/src`, then as `stopan` (`sudo runuser -l stopan`):
`podman build --format docker` (OCI would drop the `HEALTHCHECK`), tags
`localhost/stopan:<rev>` and `:latest`, `systemctl --user daemon-reload`
and `restart stopan`, waits up to two minutes for `/up`, keeps the three
newest revision images.

## Acceptance

- DNS A record of `stopan.linuxfan.org` is the server's address.
- `http://stopan.linuxfan.org/` redirects to `https://`.
- The certificate is issued by Let's Encrypt for `stopan.linuxfan.org`,
  the chain verifies, and it is inside its validity dates.
- HTTPS responses carry HSTS, the Content Security Policy, `X-Frame-Options`
  / `frame-ancestors`, `X-Content-Type-Options`, and secure, HttpOnly
  session cookies; none are relaxed for the deployment.
- `https://stopan.linuxfan.org/up` returns 200, the sign-in page renders,
  `/users/sign_up` redirects to sign-in.
- The app listens only on `127.0.0.1:3183` (no `0.0.0.0` or public
  listener).
- `stopan.service` is active and enabled for the `stopan` user, linger is
  on, Podman shows the container healthy, processes run as `stopan`.
- After restarting the service, and after a server reboot, the app comes
  back without anyone logging in.
- The running image tag equals the deployed git revision.
- g0no (`g0no.linuxfan.org`, `g0no.service`, `127.0.0.1:3182`) is unchanged
  and still answers.

## Deployed resources (2026-10-26)

| resource | value |
|----------|-------|
| ISPConfig site | domain_id 25, client 1, system user `web25`, `/var/www/clients/client1/web25`, SSL + Let's Encrypt + rewrite to HTTPS, proxy in Apache directives |
| vhost (ISPConfig-generated) | `/etc/apache2/sites-available/stopan.linuxfan.org.vhost`, enabled as `100-stopan.linuxfan.org.vhost` |
| certificate | Let's Encrypt (ECDSA) for `stopan.linuxfan.org`, `/etc/letsencrypt/live/stopan.linuxfan.org_ecc/`, renewal by `certbot.timer` (`/etc/letsencrypt/renewal/stopan.linuxfan.org_ecc.conf`) |
| system user | `stopan` uid 994 / gid 991, home `/srv/stopan` (750), subuid/subgid 2100000:65536, linger on |
| unit | `~stopan/.config/containers/systemd/stopan.container` -> user unit `stopan.service` |
| image | `localhost/stopan:fa69269` = `:latest` (2026-10-27; `:e553a58` kept for rollback) |
| backups | `/srv/stopan/backups` (700): `pre-deploy-e553a58.sqlite3` (600), taken before the 2026-10-27 update |
| data / settings | `/srv/stopan/storage` (700), `/srv/stopan/stopan.env` (600) |
| listener | `127.0.0.1:3183` only |
| Remote API user | `stopan_deploy`, 127.0.0.1, Sites Domain functions |
| root-only files | `/root/.config/stopan/ispconfig-remote.env` (600, dir 700), `/root/stopan/` (700: scripts, site JSON, `admin-password.txt`) |

## Verified (2026-10-26)

- DNS A = the server, no AAAA. `http://` -> 301 `https://`.
- Certificate: subject and SAN `stopan.linuxfan.org`, issuer Let's Encrypt
  YE1, chain verifies, valid 2026-10-26 to 2027-01-24.
- Headers on `/users/sign_in`: HSTS (max-age 63072000, includeSubDomains),
  CSP (self only, `frame-ancestors 'none'`), `X-Frame-Options`,
  `X-Content-Type-Options: nosniff`, `Referrer-Policy`; session cookie
  `secure; httponly; samesite=lax`. Nothing relaxed.
- `/up` 200 (public and loopback); `/` and `/users/sign_up` redirect to
  sign-in; admin sign-in through Apache reaches `/admin` and the queue
  (200); the stylesheet is served as readable `text/css`.
- Only `127.0.0.1:3183` listens (0 public listeners); processes (conmon,
  pasta, catatonit, thrust, ruby) run as `stopan`; container healthy,
  user 1000:1000, `no-new-privileges`, no added capabilities.
- `stopan.service` active, `Restart=always`, generated from the quadlet,
  linger on; `apache2ctl configtest` OK; the proxy directives are in the
  ISPConfig record, so resyncs keep them.
- Restart: `systemctl --user restart stopan` -> `/up` 200 within seconds;
  boot path: `systemctl restart user@994.service` (stopan's manager only)
  -> service started by linger and `/up` 200. A full server reboot was not
  done (it would interrupt every other site).
- g0no `/up` 200 and its listener on 3182 before and after; nothing of
  g0no was changed.

## Update 2026-10-27 (revision fa69269)

- Before: a consistent copy of the database with `VACUUM INTO` run inside
  the container (`bin/rails runner`), moved to `~stopan/backups/`
  (`pre-deploy-<old rev>.sqlite3`, mode 600). Do this before every deploy
  that brings migrations.
- `DEPLOY_HOST=<ssh host> make deploy`: built and restarted, `/up`
  answered; the entrypoint's `db:prepare` ran the five new migrations
  (AddNotificationSettingsToUsers, AddSharingToTickets,
  CreateNotifications, AddEditing, AddMarkdownToMessages), all additive.
- Checked: schema version 20261027120000, no pending migrations, the new
  tables and columns exist, existing tickets and users kept; container
  healthy; only `127.0.0.1:3183` listens; `http://` -> 301 `https://`;
  HSTS, CSP, `X-Frame-Options`, `nosniff` and a secure HttpOnly session
  cookie unchanged; `/users/sign_up` redirects to sign-in; an unknown
  share link is 404; g0no `/up` 200.
- `/cable` answered 404 through Apache after the deploy, because the
  `ProxyPass` line had no `upgrade=websocket`; fixed the same day (next
  section). `SMTP_ADDRESS` is not set, so no email is sent (the log says
  so).
- Rollback of this release: as `stopan`, `podman tag localhost/stopan:e553a58
  localhost/stopan:latest`, restore the backup over
  `~/storage/production.sqlite3` (with `podman unshare`, service stopped),
  then `systemctl --user restart stopan`.

## WebSocket proxy (2026-10-27)

Operator: "add upgrade=websocket through the ISPConfig API".

- The site record was read with `sites_web_domain_get` (primary_id 25)
  and saved as `/root/stopan/site-25-before-websocket.json` (root, 600)
  for a rollback.
- `sites_web_domain_update` (client 1, primary_id 25) changed only the
  one line `ProxyPass / http://127.0.0.1:3183/ retry=0` to end in
  `upgrade=websocket`. The method fills `log_retention` and the `pm_*`
  fields with defaults when they are missing, so the call passed their
  current values (30, 10, 2, 1, 5) to leave them unchanged. The request
  is `/root/stopan/site-25-websocket-update.json`.
- ISPConfig's cron regenerated the vhost within about 50 seconds and
  restarted Apache (a restart, not a graceful reload: every site on the
  server was unavailable for a few seconds). `apache2ctl configtest`
  OK; Apache active; Stopan and g0no `/up` 200.
- Checked: a WebSocket upgrade to `/cable` with the site's own `Origin`
  answers 101; with a foreign `Origin` 404 (Action Cable's same-origin
  check).
- Rollback: `sudo /root/stopan/bin/ispconfig-remote sites_web_domain_update`
  with the old line (built from the saved record the same way).

## ModSecurity and the session cookie (2026-10-27)

Apache runs ModSecurity 2.9 with the OWASP CRS 3.3 (`SecRuleEngine On`,
server-wide). The operator got 404 on `/`: CRS rule 941120 ("XSS Event
Handler Vector") matched `REQUEST_COOKIES:_stopan_session`. The cookie is
random base64 (AES-GCM encrypted, new on every response), so now and then
it contains something like `7onAbcd=-`; the request is denied with 403,
the 403 error document is missing, so the browser shows 404. Because the
blocked response never replaces the cookie, that browser stays locked out
until the cookie is deleted.

Fix (operator approved): the site's Apache directives end with

```
<IfModule security2_module>
	SecAction "id:13183,phase:1,pass,nolog,ctl:ruleRemoveTargetByTag=OWASP_CRS;REQUEST_COOKIES:_stopan_session"
</IfModule>
```

- It removes only that one cookie from the CRS rules' targets, per request,
  for this site. URLs, arguments, headers and other cookies are still
  inspected. It is safe because Rails rejects any `_stopan_session` value
  that does not decrypt and authenticate before using it.
- The configure-time form `SecRuleUpdateTargetByTag "OWASP_CRS"
  "!REQUEST_COOKIES:_stopan_session"` was tried first and had no effect:
  inside a VirtualHost it does not change rules loaded at server level.
- Applied with `sites_web_domain_update` the same way as the WebSocket
  change (current `log_retention`/`pm_*` passed). Records before each
  step: `/root/stopan/site-25-before-modsecurity.json` and
  `site-25-before-secaction.json` (root, 600). ISPConfig restarted Apache
  twice (a few seconds each for every site).
- Checked: a session cookie with the pattern -> 302 to sign-in (app);
  the same pattern in another cookie -> blocked; `<script>` in the query
  string -> blocked; no cookie -> 302; HSTS, CSP, X-Frame-Options,
  nosniff present; `/cable` 101; `configtest` OK; g0no `/up` 200.
- Rollback: `sites_web_domain_update` with the `apache_directives` of
  `site-25-before-modsecurity.json`.
- Rule id 13183 is in the local range and was unused on the server.

## Update 2026-10-27 (revision 3e50793)

- Before: checked the data the release changes (two administrators, no
  agents or requesters without an organization, one open ticket, no
  resolved or closed tickets), then a `VACUUM INTO` copy of the database
  to `~stopan/backups/pre-deploy-fa69269.sqlite3` (mode 600). In the
  runner the target path must be an SQL string in single quotes
  (`connection.quote`), not double quotes.
- `DEPLOY_HOST=<ssh host> make deploy`: built and restarted, `/up`
  answered; `db:prepare` ran the new migrations up to
  `MergeResolvedAndClosedIntoDone` (20261027220000), which cannot be
  undone.
- Checked: schema version 20261027220000, no pending migrations,
  `tickets.done_at` exists and `closed_at` is gone, tickets and users
  kept; container healthy; only `127.0.0.1:3183` listens; `http://` ->
  301 `https://`; HSTS, CSP, `X-Frame-Options`, `nosniff` and the secure
  HttpOnly session cookie unchanged; `/users/sign_up` and `/tickets/board`
  redirect to sign-in; `/cable` answers 101 to a WebSocket upgrade over
  HTTP/1.1 (curl over HTTP/2 gets 404, as HTTP/2 has no Upgrade); g0no
  `/up` 200.
- Still not set in `stopan.env`: SMTP, `TRUSTED_PROXIES`,
  `MAILBOX_POLLING` (todo).
- Rollback of this release: the database must go back with the image,
  because the Done migration rewrote statuses. As `stopan`: stop the
  service, tag `localhost/stopan:fa69269` as `latest`, restore
  `backups/pre-deploy-fa69269.sqlite3` over `~/storage/production.sqlite3`
  (with `podman unshare`), start the service. Changes made after the
  deploy are lost.

## Rollback

Resources the deployment creates, and how to remove them in order:

1. App: as `stopan`, `systemctl --user stop stopan`; delete
   `~/.config/containers/systemd/stopan.container`; `systemctl --user daemon-reload`.
   To roll back only a release: tag an older `localhost/stopan:<rev>` as
   `latest` and restart.
2. Website: `echo '{"primary_id": 25}' | sudo /root/stopan/bin/ispconfig-remote sites_web_domain_delete -`. ISPConfig removes the vhost, the site
   directory `/var/www/clients/client1/web<id>` and the certificate
   configuration on its next cron run. Never delete the vhost file by hand.
3. Data: back up `~stopan/storage` if it is kept, then
   `loginctl disable-linger stopan`, `userdel -r stopan`, and remove its
   lines from `/etc/subuid` and `/etc/subgid`
   (`usermod --del-subuids ... --del-subgids ...` before `userdel`).
4. Access: delete the remote user in the panel and
   `/root/.config/stopan/ispconfig-remote.env`.

None of these touches g0no's user, container, site, port or files.

## Security Note

Keep `stopan.env`, the admin password file and the remote API file at
mode 600 and out of git. Limit the remote user to `127.0.0.1` and to the
"Sites Domain functions"; delete it when deployments no longer need it.
Password reset emails do not work until SMTP is configured (auth.md), so
the admin password must not be lost. Back up `~stopan/storage`; nothing
else holds the data.
