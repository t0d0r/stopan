# 2026-10-31 - attachments: gap analysis and request size limit

## Gap analysis (before coding)

Compared specs/attachments.md and the attachment parts of api.md,
roles.md, sharing.md, organization-mail.md, notifications.md,
queues.md and public-form.md with the code and tests.

Already in place and tested:

- Limits (5 files, 10 MB each, allow-listed types detected from bytes
  and name) in `Attachable`; a refused file makes the record invalid
  (test/models/ticket_test.rb, comments_controller_test.rb).
- Uploads in the new ticket form and the reply/note composer (requesters
  and staff); API multipart for new tickets (test/integration/api_test.rb).
- Authorized downloads and previews (`AttachmentsController`,
  `Api::V1::AttachmentsController`, shared links), `send_file` in chunks
  for the Disk service, inline only for previewable kinds with a
  sandboxing CSP (attachments_controller_test.rb,
  shared_tickets_controller_test.rb).
- Mail ingestion keeps allowed attachments and names the refused ones
  (mailbox_message_test.rb); emails list file names only.
- Flushing an organization purges its blobs.
- The public request form has no files on purpose (public-form.md).
- The todo item "previews and downloads load the whole file into memory"
  is in the g0no archive and does not apply (send_file streams).

Gaps:

1. No limit on the size of a request. The 5 x 10 MB limits are checked
   only after the whole body has been received; Puma and Rack write
   multipart file parts to temporary files first. Any request, also to
   pages that need no sign-in, can make the server store an arbitrarily
   large body on disk. Neither Puma (`http_content_length_limit`, default
   none) nor Thruster in the image (`MAX_REQUEST_BODY`, default 0 = none)
   is configured.
2. Files on replies and notes through the API
   (`POST /api/v1/tickets/:number/comments` with `comment[files][]`) have
   no test, nor a refused file type there.
3. specs/attachments.md "Acceptance" does not name the API and mail
   tests.

Out of scope (not in the spec, would be new features): files on the
public form, drag and drop or paste into the composer, a client-side
size check before upload, virus scanning, thumbnails (roadmap.md).

## Plan

1. One limit for the whole request, `MAX_REQUEST_BODY` (bytes), default
   52 MiB: 5 files x 10 MiB plus 2 MiB for the text fields and multipart
   overhead. `0` turns it off, as in Thruster.
   - Puma: `http_content_length_limit` in config/puma.rb, so `bin/rails
     server`, `make run`, the dev container and production all refuse a
     larger body with 413 before reading it (Content-Length, or counted
     for chunked bodies).
   - Image: `ENV MAX_REQUEST_BODY` in the Dockerfile, so Thruster refuses
     it already in front of Puma.
   - A test that keeps the default above the attachment limits, so
     raising `Attachable::MAX_FILES` or `MAX_SIZE` without the request
     limit fails.
2. API test: reply files through the API, a requester's `internal`
   flag with a file still becomes a public reply, a refused type is 422
   `invalid` naming the file and saves nothing.
3. Specs: attachments.md (request size, acceptance), docker.md
   (variable), deploy.md (Apache and ModSecurity must allow at least the
   same size; still to check in production).

No production deployment, no external calls, no commits.

## Done

- config/puma.rb: `http_content_length_limit` from `MAX_REQUEST_BODY`,
  default 52 MiB; `0` turns it off; a non-number or a negative value
  stops Puma at boot.
- Dockerfile: `ENV MAX_REQUEST_BODY="54525952"`, so Thruster in the image
  refuses the same size in front of Puma.
- test/config/puma_test.rb (new): reads the real config/puma.rb through
  `Puma::Configuration`; the default is 52 MiB and at least
  `MAX_FILES` x `MAX_SIZE` + 2 MiB; `MAX_REQUEST_BODY` sets it, `0` turns
  it off, `lots` and `-1` raise; the Dockerfile carries the same value.
- test/integration/api_test.rb: replies and notes with files through the
  API (requester's `internal` flag stays public; a staff note's file is
  404 for the requester; a refused type is 422 `invalid` naming the file
  and stores no comment and no blob).
- specs: attachments.md ("Request size", acceptance, security note),
  docker.md (`MAX_REQUEST_BODY`), deploy.md ("Request size", an
  acceptance line for uploads through Apache).
- todo: section "Attachments: request size limit".

## Validation

- Baseline before the change: `bin/rails test` 516 runs, 3557
  assertions, 0 failures, 0 errors.
- After: `bin/rails test` 520 runs, 3582 assertions, 0 failures, 0
  errors, 0 skips; `bin/rubocop` 274 files, no offenses; `bin/brakeman`
  no warnings; gitleaks `dir` on every changed path: no findings (the
  whole tree reports findings only in ignored, generated `log/test.log`
  and `tmp/cache`).
- The commands of `make lint` and `make test` were run directly with the
  gems of the main checkout (`BUNDLE_PATH`): `make deps` in a worktree
  would set a relative bundle path and install gems over the network.
- By hand, local only: `bin/rails server` with Thruster in front: 1 MiB
  reaches the app; 53 MiB with Content-Length and 53 MiB chunked get 413
  from Puma (`Puma::HttpParserError: Payload Too Large` in its log).
  Thruster alone (Puma behind it with `MAX_REQUEST_BODY=0`): 413 for
  both 53 MiB bodies, while the same body sent straight to that Puma
  reached the app. Thruster refuses while forwarding, so a backend that
  answers without reading the body (seen with a plain Python server) gets
  no 413 from it; Puma reads every body first, so in the image the two
  limits hold together. The app answered 500 in these checks only
  because the worktree has no migrated development database.

## State

- All changes are committed in one commit on branch
  `attachments-request-limit` in the worktree
  `.claude/worktrees/attachments-request-limit`, made from local main
  (30d516d, one commit ahead of origin). Not merged into main, not
  pushed. The main checkout is unchanged apart from the untracked
  `.claude/` directory that holds the worktree (not in .gitignore).
- No production change: the server, Apache, ModSecurity and the database
  were not touched.

## Open

- Merge branch `attachments-request-limit` into main (todo).
- Production: check Apache's `LimitRequestBody` and ModSecurity's
  `SecRequestBodyLimit` let a 52 MiB upload through (deploy.md "Request
  size"), with the open todo "check file uploads through Apache and
  mod_security in production". A deploy of this change sets the new
  limit in the container; nothing else changes for allowed uploads.
- The browser shows Puma's plain 413 text for an oversized body; a check
  in the browser before sending is not in the spec.

## Files

config/puma.rb, Dockerfile, test/config/puma_test.rb,
test/integration/api_test.rb, specs/attachments.md, specs/docker.md,
specs/deploy.md, todo/todo.md, this note.

## Run and verify

`make check` (in a normal checkout); `bin/rails test
test/config/puma_test.rb test/integration/api_test.rb`. Locally:
`bin/rails server`, then `curl -X POST --data-binary @<file over 52 MiB>
http://127.0.0.1:3000/` answers 413.

## Next step

Merge the branch into main; then, on the next deploy, check
an upload of 5 files near 10 MB through Apache (deploy.md "Request
size").
