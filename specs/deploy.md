# Production deployment

Operator, 2026-10-25: deploy Stopan to the operator's Debian server under
the public host name `stopan.linuxfan.org`, completely independent of
g0no. The website is registered only through the ISPConfig Remote API
(`sites_web_domain_add`); no direct writes to ISPConfig tables and no
hand-written Apache vhost. The app runs as rootless Podman under its own
system user on a loopback-only port, behind the ISPConfig-managed Apache
vhost, which also obtains the Let's Encrypt certificate.

## Status

**Not deployed. Blocked on ISPConfig Remote API access (2026-10-25).**
See "Blocker" below. Nothing has been changed on the server.

## Layout

| part | where |
|------|-------|
| website | ISPConfig site `stopan.linuxfan.org`, client 1 (the same client and settings as the g0no site), created with `sites_web_domain_add` from `deploy/ispconfig-site.json`: no PHP, SSL with Let's Encrypt, rewrite HTTP to HTTPS, PageSpeed off, proxy in the site's "Apache directives" field |
| proxy | the site's Apache directives (`deploy/ispconfig-site.json`): `ProxyPass / http://127.0.0.1:3183/`, `ProxyPreserveHost On`, `X-Forwarded-Proto https`, ACME challenge path excluded. They are stored in the ISPConfig site record, so a panel resync regenerates them |
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

Stopan has no WebSocket (no Action Cable), so the proxy line has no
`upgrade=websocket`.

## Settings (`~stopan/stopan.env`)

Generated on the server with umask 077 and never copied off it:
`SECRET_KEY_BASE` (`openssl rand -hex 64`) and `ADMIN_PASSWORD`
(`openssl rand -base64 24`). `APP_HOST=stopan.linuxfan.org`,
`MAILER_SENDER=no-reply@stopan.linuxfan.org`, `ADMIN_USERNAME=admin`,
`ADMIN_EMAIL` an operator-chosen address, `RAILS_FORCE_SSL=true`,
`RAILS_ASSUME_SSL=true`, `REGISTRATION_OPEN=false` (docker.md, auth.md).
The admin password is handed to the operator on the server only (a mode
600 file owned by root, deleted after the first sign-in and password
change); it is never printed in a terminal log.

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
access from `127.0.0.1`.

Not yet run against the server (no remote user exists).

## Blocker (2026-10-25)

- The ISPConfig `remote_user` table is empty: no Remote API account exists.
- No ISPConfig panel credentials or authenticated session were provided to
  the deploying agent, so it cannot create a remote user through the panel
  (System -> Remote Users).
- Not used, because they are not supported or would alter existing
  accounts: inserting a `remote_user` row with MySQL; inserting
  `web_domain` rows; a hand-written vhost; `ispc user set-password admin`
  (it would change the operator's panel password).

To unblock, the operator either:

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
   (65536 ids not overlapping any range in `/etc/subuid` and `/etc/subgid`),
   `loginctl enable-linger stopan`.
3. As `stopan` (`runuser -l stopan -s /bin/bash`), umask 077: create
   `~/storage`, `~/.config/containers/systemd`, `~/stopan.env` (Settings);
   install `deploy/stopan.container` into `~/.config/containers/systemd/`.
4. Prove `ss -Htln 'sport = :3183'` is empty, then `DEPLOY_HOST=<ssh host> make deploy`
   from the workstation: builds, starts `stopan.service`, waits for `/up`
   on `127.0.0.1:3183`. The entrypoint migrates and seeds the database.
5. Copy `bin/ispconfig-remote` and `deploy/ispconfig-site.json` to the server
   and run `bin/ispconfig-remote sites_web_domain_add deploy/ispconfig-site.json`.
   It prints the new `domain_id`; record it here.
6. Wait for the ISPConfig server cron (one minute) to write the vhost
   (`/etc/apache2/sites-enabled/100-stopan.linuxfan.org.vhost`) and to
   obtain the certificate; `sites_web_domain_get` with `primary_id` shows
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

## Rollback

Resources the deployment creates, and how to remove them in order:

1. App: as `stopan`, `systemctl --user stop stopan`; delete
   `~/.config/containers/systemd/stopan.container`; `systemctl --user daemon-reload`.
   To roll back only a release: tag an older `localhost/stopan:<rev>` as
   `latest` and restart.
2. Website: `bin/ispconfig-remote sites_web_domain_delete` with
   `{"primary_id": <domain_id>}`. ISPConfig removes the vhost, the site
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
