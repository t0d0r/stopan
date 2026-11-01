# 2026-11-01 - release of the request size limit (28361df)

## Done

- The request size limit (session/2026-10-31-attachments.md, commit
  0bc597e) was merged into main as a fast-forward, recorded in 28361df,
  and main was pushed to origin (8087b1a..28361df, including the
  earlier session commit 30d516d). `make secrets` (gitleaks on the
  history) found nothing before the push. The feature branch and its
  worktree were removed.
- Before deploying, the server's limits were checked in every file
  Apache loads: `LimitRequestBody` is not set (Apache 2.4.69 default,
  1 GiB); ModSecurity's server-wide `SecRequestBodyLimit` is 12.5 MiB
  with `Reject`, so bodies over 12.5 MiB never reached the app.
- ModSecurity: `SecRequestBodyLimit 54525952` added to the Stopan site's
  directives through the ISPConfig Remote API (record saved before,
  vhost regenerated, Apache restarted, configtest OK). Other sites and
  the server-wide file are unchanged. deploy/ispconfig-site.json carries
  the same directives as the server.
- Deployed 28361df after a `VACUUM INTO` backup
  (`pre-deploy-5fd80c0.sqlite3`); no migrations.
- Checked after the deploy (specs/deploy.md "Update 2026-11-01"): the
  usual health checks, data kept, `MAX_REQUEST_BODY` in the container,
  413 for 53 MiB from the app itself and through Apache, 20 MiB reaching
  the app through Apache, g0no unchanged.

## Decisions

- The ModSecurity limit is raised for the Stopan site only, to the same
  52 MiB as the app, instead of in the server-wide file, so other sites
  keep their stricter limit.

## Open

- A real upload of 5 files near 10 MB by a signed-in user on a test
  ticket (todo); the size path is checked, the attachment flow in
  production is not.
- The older todo "check file uploads through Apache and mod_security in
  production" now has the size part answered; the content of real files
  (PDF, Office) against the CRS rules is still unchecked.

## Files

specs/deploy.md ("Request size", "Update 2026-11-01"),
deploy/ispconfig-site.json, todo/todo.md, this note.

## Run and verify

`make check`; `https://stopan.linuxfan.org/up`; rollback steps in
specs/deploy.md "Update 2026-11-01" and "Request size".

## Next step

Upload 5 files near 10 MB on a test ticket as a signed-in user, check
they download, then delete the ticket.
