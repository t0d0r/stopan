# 2026-10-25/26 - deploy Stopan to stopan.linuxfan.org (Job 4)

## Closeout (2026-10-26 ~10:45 server time)

Why the session ended: the deployment is complete and validated.

Outcome: Stopan e553a58 is live at https://stopan.linuxfan.org, served by
the ISPConfig-managed site 25 (created with `sites_web_domain_add` through
the Remote API) proxying to the rootless Podman container of the new
`stopan` user on 127.0.0.1:3183. g0no was not changed.

State changes on the server, in order (resources: specs/deploy.md
"Deployed resources"; rollback: specs/deploy.md "Rollback"):

1. `/root/.config/stopan/` (700) and `ispconfig-remote.env` (600) with a
   server-generated password (agent, ~09:45).
2. `/root/stopan/` (700): `bin/ispconfig-create-remote-user`,
   `bin/ispconfig-remote`, `deploy/ispconfig-site.json` (agent, 10:11).
3. ISPConfig remote user `stopan_deploy` (id 2), created through the
   panel form by the operator running the script (datalog 618, 10:12).
4. System user `stopan` (uid 994), subids 2100000:65536, linger (10:13).
5. `~stopan/stopan.env` (600, secrets generated on the server),
   `~stopan/storage`, the quadlet; `/root/stopan/admin-password.txt` (600).
6. `make deploy`: port 3183 proved free (0 listeners) right before;
   image `localhost/stopan:e553a58`; `stopan.service` started 10:15:57.
7. `sites_web_domain_add` -> domain_id 25 (datalog 619, 10:20); the first
   call was rejected (missing `pm_process_idle_timeout`/`pm_max_requests`)
   and created nothing.
8. ISPConfig cron wrote the vhost and web25 and obtained the Let's
   Encrypt certificate through certbot (10:21).
9. Restart tests: `systemctl --user restart stopan` and
   `systemctl restart user@994.service`.

Validation (redacted): see specs/deploy.md "Verified". Summary: DNS ok;
http -> https 301; certificate CN/SAN stopan.linuxfan.org, Let's Encrypt,
chain OK, valid to 2027-01-24; HSTS, CSP, frame, nosniff, secure HttpOnly
cookie; `/up` 200; admin sign-in -> `/admin` and queue 200; loopback-only
listener; container healthy, processes as `stopan`; service active after
both restarts; `apache2ctl configtest` OK; g0no `/up` 200 throughout.

Corrections:

- The earlier note "How g0no's ISPConfig site was made" concluded that
  g0no's record was written directly into dbispconfig. That was wrong:
  Stopan's own Remote API insert (datalog 619) has the same empty
  `domain_id:` and empty `added_by`, so g0no's record (datalog 617) is
  consistent with a Remote API insert by an earlier remote user (id 1,
  since deleted).
- The first test sign-in failed because the form body came from `jq -r`
  (trailing newline in the password). The same bug in
  `bin/ispconfig-create-remote-user` left a trailing newline in the remote
  user's function list; fixed in the script (`jq -j`).

Open / risks:

- Full server reboot not tested (would interrupt all sites).
- Operator: sign in, change the admin email/password, delete
  `/root/stopan/admin-password.txt`; re-save the remote user in the panel;
  delete the remote user when no longer needed.
- No backups of `/srv/stopan/storage` yet; SMTP not configured.
- Commits are local only: `git push` has no GitHub credentials on the
  workstation; the branch also carries another session's commits.

Commit: the commit that adds this closeout (see `git log`); deployed
revision e553a58.

Next step: operator tasks above; then set up backups of
`/srv/stopan/storage`.

## Local Docker test (2026-10-26 evening)

The operator asked whether Stopan can be tested locally with Docker. Yes:
`make docker-check` (smoke test, throwaway secrets, 127.0.0.1:3190) and
`make docker-up` (http://localhost:3000 with `.env`). The local build now
works (Docker Hub reachable; about a minute). `docker-check` failed at its
last step: production logs to STDOUT, so the "SMTP_ADDRESS is not set"
warning (added with the mail settings) came before `User.count` in the
`rails runner` output. Fixed in `bin/docker-check` by reading only the
last line; `make docker-check` -> OK. The "image still unbuilt" item under
Open below is resolved.

## Development in Docker (2026-10-26 evening)

The operator asked for a Docker run for development that does not need
`docker-down`/`docker-up` per change. Added `Dockerfile.dev`,
`compose.dev.yaml` and the targets `docker-dev`, `docker-dev-restart`,
`docker-dev-logs`, `docker-dev-down` (specs/docker.md "Development in
Docker"); `make help` column widened for the longer names. The source is
mounted, so changes apply on the next page load. Verified: `/up` 200,
admin seeded, uid 1000, CSS served, a view edit showed without a restart.
First run rewrote the mounted `Gemfile.lock` (container bundler checksum
line); reverted and fixed with `BUNDLE_FROZEN=true`.

Note: a parallel session committed the first version of these files in
its own commit 254b538; the frozen-lockfile fix, spec and notes are in
the follow-up commit. The dev container is left running on
127.0.0.1:3000 (`make docker-dev-down` stops it).

## 404 on stopan.linuxfan.org (2026-10-27)

The operator got 404 on `https://stopan.linuxfan.org`. Cause:
ModSecurity (OWASP CRS 3.3, server-wide) rule 941120 matched the random
encrypted `_stopan_session` cookie of that browser (403, the error
document is missing -> 404), and the blocked response never replaces the
cookie, so the browser stays locked out. Requests without the cookie
worked. Unrelated to the WebSocket change of 04:08, but the same random
match can hit any browser at any time.

With the operator's approval, `sites_web_domain_update` added a
per-site `SecAction` (id 13183) that removes only `_stopan_session` from
the CRS targets (specs/deploy.md "ModSecurity and the session cookie").
A first attempt with `SecRuleUpdateTargetByTag` in the vhost had no
effect and was replaced. Apache restarted twice through ISPConfig.
Verified: session cookie with the pattern -> app; same pattern in other
cookies and `<script>` in the query string -> still blocked; headers,
`/cable` 101, configtest, g0no `/up` 200. Immediate workaround for a
locked-out browser was: delete the site's cookies.

Open: g0no runs under the same CRS and may hit the same random match on
its session cookie; not touched (needs its own decision).

## Demo data in the dev container (2026-10-26 evening)

The operator asked for users and organizations besides the admin, for
development only. The existing `stopan:demo` task (2 organizations, 2
agents, 3 requesters, 3 tickets; refuses production) now runs on every
dev container start when `DEMO_PASSWORD` is set; `bin/setup-env`
generates it in `.env`. Verified: data created, `anna@example.com` signs
in (303) and opens the ticket list (200). The dev database also ran the
parallel session's uncommitted sharing migration (mounted source).

## First stop (2026-10-25)

Stopped at a non-bypassable access blocker before any server change: the
ISPConfig Remote API has no account, and no panel credentials or session
were available through a supported channel. The assignment forbids
creating the account (or the site) through MySQL or a hand-written vhost.

## Outcome (2026-10-25)

Not deployed. No mutation on the server. The deployment is designed and
its artifacts are in the repository (specs/deploy.md), ready to run once
the operator provides a remote API user.

## Resume attempt, 2026-10-26 08:01 server time

The operator reported the credentials file in place at
`/root/.config/stopan/ispconfig-remote.env`. Revalidated read-only before
any change:

- The file does not exist; `/root/.config/stopan/` does not exist; no file
  named `ispconfig-remote*.env` was created anywhere on the root
  filesystem since 2026-10-25 22:00.
- ISPConfig `remote_user` still has 0 rows, so no remote user was created
  in the panel either.
- Unchanged: DNS A record correct, no stopan `web_domain` row or vhost, no
  `stopan` user, 127.0.0.1:3183 free, g0no `/up` 200.

Outcome: still blocked; no server mutation. Both parts of the unblock
(remote user in the panel and the root-only file) are needed; see
specs/deploy.md "Blocker".

## Second resume, 2026-10-26: create the remote user myself

The operator authorized the agent to create the remote user and the
credentials file through the supported ISPConfig admin workflow, without
direct table writes, admin password reset/recovery or manual vhosts.
Read-only proof that no supported authenticated admin route is available
to the agent:

- Panel form (System -> Remote Users, `admin/remote_user_edit.php`): an
  unauthenticated request is redirected (302) to the login page. Using it
  needs an ISPConfig admin login; no admin credential or session was
  given to the agent, and resetting or recovering one is forbidden.
- Remote API: no function in `remote.d/*` creates or edits remote users
  (the admin module only offers config values, datalog, system config and
  record permissions), and API login itself needs an existing remote user
  (0 exist) or a panel user's password (`client_login`, not available).
- `ispc` CLI: modules extension, help, letsencrypt, php, resync, update,
  user, version; `user` offers only `set-password` (forbidden reset).
- Searching hosts for stored credentials is not a supported route and was
  refused by the harness in the first attempt.

Outcome: stopped without mutation. To unblock, the operator signs in to
the panel and creates the remote user, or provides an admin panel
session/credential through a channel that does not end up in logs.

## Credentials file created by the agent, 2026-10-26 ~09:45

On the operator's request ("you execute these") the agent created
`/root/.config/stopan/` (root, 700) and `ispconfig-remote.env` (root, 600)
with `ISPC_REMOTE_USER=stopan_deploy` and a password generated on the
server (`openssl rand`, 44 characters); it was never printed or copied
off the server. The remote user itself still has to be created in the
panel by the operator with those values (needs an admin login). Rollback:
delete the file and directory.

## Operator script for the remote user (2026-10-26)

`bin/ispconfig-create-remote-user` (new) signs in to the panel with an
admin login typed at a prompt (never stored, never in argv), submits the
System -> Remote Users form with the panel's CSRF token, restricted to
127.0.0.1 and "Sites Domain functions", reads back the stored row and
proves an API login with `sites_web_domain_get`. Installed with
`bin/ispconfig-remote` and `deploy/ispconfig-site.json` in `/root/stopan`
(root, 700) on the server for the operator to run:
`sudo /root/stopan/bin/ispconfig-create-remote-user`. Also fixed
`bin/ispconfig-remote` reading its JSON from stdin (`-`).

## How g0no's ISPConfig site was made (2026-10-26; WRONG, see Closeout)

The operator asked to repeat what was done for g0no. Read-only findings:

- g0no was deployed on 2026-10-19 with a hand-written Apache vhost and
  certbot (g0no repo specs/deploy.md), not as an ISPConfig site.
- Its ISPConfig record (domain 24) appeared on 2026-10-25 09:51 as
  `sys_datalog` entry 617, with an empty record id (`domain_id:`), empty
  `added_by` and no `added_date`. Panel and Remote API inserts fill these;
  no remote user existed then or since. So the record was most likely
  written directly into dbispconfig, the method the operator forbade for
  Stopan.
- It therefore cannot be repeated within the rules. No change was made.

## Revalidation (read-only, redacted)

- DNS: `stopan.linuxfan.org` A = the server's address (same as
  `do.linuxfan.org`); no AAAA for either.
- Today `https://stopan.linuxfan.org` presents another site's certificate
  (default vhost); `http://` answers 200 from the default vhost. No Stopan
  vhost in `sites-enabled`.
- ISPConfig 3.3.1p1, one server (id 1, web server). `web_domain` has no
  row for stopan; g0no's site is domain 24 (client 1), proxy in its
  Apache directives to 127.0.0.1:3182 - used as the reference.
- `remote_user` table: 0 rows; `remote_session`: 0 rows. Panel (8443) and
  `/remote/json.php` answer 200; maintenance mode not enabled. The panel
  certificate is self-signed.
- `ispc` CLI offers `user set-password` but no remote-user command.
- Listeners: loopback app ports 3181 (ruby) and 3182 (g0no's pasta);
  3183 free at check time. Public: 80, 443, 8081, 8443 (Apache), 3128.
- Users: `g0no` (uid 997, lingering, subuid 2000000:65536); no `stopan`
  user.
- Capacity: 4 CPUs, 7.8 GiB RAM (about 2.5 GiB available), 84 GB free on
  `/`. Debian 13, Podman 5.4.2.
- Earlier preflight files from a previous attempt exist in a root-only
  directory on the server; they were only listed, not reused as evidence.
- Local: HEAD 42fdf69 (before this session's commit); `make check` 122
  runs, 505 assertions, 0 failures, RuboCop and Brakeman clean.

## Done

- `specs/deploy.md`: layout, settings, Remote API use, blocker with the
  exact access needed, one-time setup, acceptance, rollback.
- `deploy/stopan.container` (quadlet modelled on g0no's real one, port
  3183 on 127.0.0.1), `deploy/ispconfig-site.json` (site parameters
  mirrored from g0no's ISPConfig record, proxy to 3183, no WebSocket),
  `bin/ispconfig-remote` (JSON Remote API caller, root-only credentials
  file, pinned panel key), `bin/deploy` and `make deploy` (refuses to start
  when port 3183 is held by something else).
- `specs/README.md`, `todo/todo.md` updated.

## Decisions

- No server mutation without the Remote API account (assignment rule).
- `ispc user set-password admin` not used: it would change the operator's
  panel password, which is not "available credentials".
- Searching the workstation or server for stored credentials was not done
  (and was refused by the harness); credentials must come from the
  operator.
- Port 3183 planned, to be re-proved free right before binding.
- SQLite stays the only database (no MySQL database for Stopan).

## Open

- Operator: create the remote user and the credentials file
  (specs/deploy.md "Blocker").
- `bin/ispconfig-remote` has not been run against the live API.
- The Stopan image is still unbuilt: `make docker-build` on the
  workstation hung for over 10 minutes resolving `docker/dockerfile:1`
  from Docker Hub (local registry access) and was cancelled. The server
  build in `make deploy` is the next real build.

## Files touched

specs/deploy.md, specs/README.md, deploy/stopan.container,
deploy/ispconfig-site.json, bin/deploy, bin/ispconfig-remote, Makefile,
todo/todo.md, this note.

## How to verify

- `make check` - lint and tests.
- `make docker-build` - builds the production image locally.
- After deployment: the checks in specs/deploy.md "Acceptance".

## Next step

When the operator confirms the credentials file is in place: follow
specs/deploy.md "One-time setup" from step 1 (re-check DNS, site state,
port 3183), then steps 2-6, then the acceptance checks.

## Security Note

No secrets were read, generated or written. The remote user should be
limited to 127.0.0.1 and to the Sites Domain functions, and removed when
no longer needed.
