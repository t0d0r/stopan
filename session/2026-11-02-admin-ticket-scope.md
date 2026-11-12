# 2026-11-02 - super administrators see only their organizations' tickets

## Done

- Production: two super administrators became agents with the
  organization admin mark on their only organization (recorded in
  session/2026-10-29-org-admins.md).
- Super administrators now see tickets only of organizations they are a
  member of (specs/roles.md "Super administrators see tickets of their
  own organizations only"). Specs also updated: org-admins.md,
  tickets.md "Deleting", sharing.md "Admin", presence.md, api.md.
- Code:
  - `Ticket.visible_to` no longer has an exception for admins.
  - `User#visible_organizations` returns the user's own organizations.
  - `Ticket.assignable_staff` returns the organization's active staff;
    the assignee validation needs membership for admins too.
  - `TicketsController#create` limits new tickets to own organizations
    for every staff role.
  - `find_ticket_for_page` covers deleted tickets through `AdminScope`
    for both kinds of administrator.
  - `AdminScope#deleted_tickets`: a super administrator's own
    organizations. The API's deleted tickets use the same scope.
  - The overview's shared list is limited to visible tickets.
  - The presence requester count is limited to the reader's
    organizations for everyone.
  - The ticket table's assign menu offers the organization's staff.
- Tests:
  - fixtures: the test admin is a member of both organizations
    (`admin_acme`, `admin_globex`);
  - new tests in `test/controllers/agent_scope_test.rb`: a super
    administrator outside an organization, and one getting no
    notifications;
  - `ticket_test.rb` visible_to, the report, seeds and org admin tests
    adjusted.

- Emails to the requester (specs/notifications.md "Emails to the
  requester", timeline.md "Events", data-model.md):
  - `tickets.email_requester`, migration `AddEmailRequesterToTickets`,
    default on;
  - in the composer, for staff while "Public reply" is chosen, an "Email
    the requester" toggle (`role=switch`). It saves at once through
    `RequesterMailsController#update` (POST with `_method=patch`, Turbo
    fetch). Without JavaScript it comes with the reply
    (`CommentsController#create`). The warning under it names the
    address and says the mail leaves Stopan;
  - `Ticket#switch_requester_mail!` writes `mail_switched`;
  - `TicketNotifier` skips the requester's email when the switch is off
    and records `mail_skipped switched_off`. The in-app notification
    still goes, and no share link is made;
  - `TicketMailer` records `mail_sent` (`after_deliver`),
    `mail_skipped no_smtp` (message not performed) and `mail_failed`
    (`rescue_from` while delivering, logged, not raised), only for the
    requester;
  - mail events skip `TicketNotifier.collect`;
  - tests: `test/models/requester_mail_test.rb` and
    `test/controllers/requester_mails_controller_test.rb`;
  - checked in the dev browser: on, off, and the event after a reload.

- Followers and Cc (specs/followers.md; README, roles.md, notifications.md,
  organization-mail.md, timeline.md, data-model.md and roadmap.md
  updated):
  - migrations `CreateTicketFollowers` (unique ticket and user; the
    adder is nullified when that user is deleted) and
    `AddDetailToTicketEvents`;
  - `TicketFollower`: active members of the organization, never the
    requester; the kind comes from the role;
  - `Ticket`:
    - `follow!`, `add_cc!` (finds or creates the requester and the
      membership, like mailbox mail; refuses staff, deactivated users,
      the requester and duplicates) and `remove_follower!`;
    - `cc_suggestions` from the mail headers;
    - `customer?`, `cc?`, `customer_emails`;
    - automatic follow for staff authors;
    - Cc lists refresh live;
  - `Ticket.visible_to` gives requesters their own tickets and their Cc
    tickets. `TicketFilter#own` follows it, and "My tickets" shows a "Cc"
    tag;
  - `TicketPolicy`: a Cc replies and edits their own public replies;
    resolve, edit and share stay with the requester;
  - `TicketNotifier` adds followers as candidates. The email switch
    covers every Cc. `TicketMailer` records customer mails with the
    address, and the reason or error goes in `detail`. Mail reasons
    `follower` and `cc` were added;
  - `MailboxMessage`: an email from a Cc becomes their public reply;
  - `TicketFollowersController` and the `_followers` panel (People).
    Follower events are internal and quiet;
  - tests:
    - `test/models/ticket_follower_test.rb`;
    - `test/controllers/ticket_followers_controller_test.rb`;
    - `test/integration/cc_access_test.rb`;
    - the mail record tests were updated.
    `make check` passes with 551 runs;
  - checked in the dev browser at 1440 and 390 px.

- In production, a person in Cc without a password got the ticket page
  link, which needs a sign-in. Fixed:
  - `Ticket#share_for_customer!` replaces `share_with_requester!`. The
    first email to a Cc makes the automatic link, protected by the
    requester's address;
  - `share_link_for` gives that link to the requester of a ticket from
    email and to every Cc;
  - the shared page also accepts a current Cc's own address on the
    automatic link (`customer_share_password?`), never on a password set
    by staff;
  - specs/followers.md and sharing.md updated, with tests.

- Deployed 99681ea, the shared link for people in Cc, with no
  migrations and every check passed (specs/deploy.md "Update 2026-11-02
  (revision 99681ea)"). An email sent before the fix still holds the
  ticket page link; the next public reply brings the shared link.

- Production backups: the 14 older copies were removed; only
  `pre-deploy-1fa5564.sqlite3` (before the follower migrations) remains.

- The shared page's password form has an eye button
  (`[data-password-field]`, `setUpPasswordField`, new `eye_off` icon):
  - it shows and hides what was typed, keeping the focus and the caret;
  - sending the form hides the text again;
  - the button is hidden without JavaScript, and is 44px on phones;
  - test in `shared_tickets_controller_test.rb`;
  - checked in the dev browser at 1440 and 390 px.

- Deployed 71df093 (the password eye), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision 71df093)").

- The password eye is now `ApplicationHelper#password_with_eye`, used on:
  - the shared page;
  - sign-in;
  - password reset (both fields);
  - the own account page (new, confirmation and current password).
  The spec moved to specs/ui.md "Password fields", the labels to
  `ui.password_show` / `ui.password_hide`, and the test is
  `test/integration/password_eye_test.rb`. Checked in the dev browser.

- The password eye is now a separate bordered button beside the field
  (flex row, the field's height, 44px on phones). Inside the field it
  covered the icons of password managers.

- Deployed 6a9194d (the password eye on sign-in and the password pages,
  beside the field), with no migrations and every check passed
  (specs/deploy.md "Update 2026-11-02 (revision 6a9194d)").

- Image preview (specs/attachments.md "Image size"):
  - the dialog takes the image's natural width up to the window, at
    least 480px;
  - an image is scaled down only when it does not fit;
  - a scaled image becomes a button for its actual size, with the media
    area scrolling;
  - PDFs and text keep the 960px dialog;
  - checked in the dev browser at 1920 and 390 px with a 2600 px and a
    420 px image.
- Backups: only `pre-deploy-1fa5564` remains in production (the rollback
  copy), so there was nothing older to remove.

- Deployed db88326 (image preview sizes), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision db88326)").

- Event lines between messages fold (specs/timeline.md "Event lines
  between messages fold"):
  - `TicketsHelper#timeline_entries` groups runs of 3 or more event
    lines; `created`, `status_changed`, `mail_failed`, `deleted` and
    `restored` stay visible and end a run;
  - `tickets/_event_run` renders the folded line ("9 events: emails,
    people, sharing", the staff-only tag, the newest time) and every
    line under it;
  - JavaScript (`setUpEventRuns`) folds the runs, keeps opened runs open
    across live refreshes and opens a run when a link points into it;
    without JavaScript and in print every line shows;
  - translations `ui.timeline.run` in en, bg and de;
  - tests in `test/helpers/tickets_helper_test.rb` and
    `test/controllers/tickets_controller_test.rb`;
  - checked in the dev browser at 1440 and 390 px: fold, open, live
    refresh, a link into a folded run.

- OpenSSF Scorecard (specs/ci.md):
  - `.github/workflows/scorecard.yml`: push to `main`, weekly, branch
    protection changes and by hand; `read-all` with
    `security-events: write` and `id-token: write` for the job; every
    action pinned to a commit SHA; results published and uploaded to
    code scanning;
  - README: the OpenSSF Scorecard badge and the workflow status badge;
  - `actionlint` passes on the workflow.

- Deployed 4c73f97 (folded event runs), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-02 (revision 4c73f97)").

- Scorecard's first run on `main` passed and both badges show. The
  first score is 3.8:
  - 10: Token-Permissions, Binary-Artifacts, Dangerous-Workflow;
  - Pinned-Dependencies 2: every action is pinned, but the base images
    in `Dockerfile` (3) and `Dockerfile.dev` (1) are not pinned by
    digest;
  - 0: no SECURITY.md, no LICENSE, no SAST, no reviewed pull requests,
    no dependency update tool;
  - Maintained 0 until the repository is 90 days old.

- `SECURITY.md` (specs/ci.md "Security policy"): latest `main` only,
  reports through GitHub's private vulnerability reporting, what a
  report holds, acknowledgement normally within 7 days, testing rules.
  No personal address in it.
- Base images pinned by digest (specs/docker.md "Pinned base images"):
  - `Dockerfile` and `Dockerfile.dev` start from
    `docker.io/library/ruby@sha256:...` (the multi-platform index of
    `ruby:4.0.7-slim`), with the tag and the update steps in a comment;
  - the `# syntax=docker/dockerfile:1` line is pinned too;
  - the `RUBY_VERSION` build argument is gone;
  - digest only, without the tag, because Podman does not always accept
    both;
  - `test/config/dockerfile_test.rb` guards the pins, the same digest
    in both files and the version against `.ruby-version`.

- `LICENSE`: BSD 2-Clause (specs/overview.md "License"); the README has
  a License section and points to `SECURITY.md` for reports.

- Deployed 436dd64, built from the pinned base image, with no
  migrations and every check passed (specs/deploy.md "Update 2026-11-02
  (revision 436dd64)").
- Private vulnerability reporting is on in the repository settings.
- Icons (specs/ui.md "Icons", 2026-11-03):
  - Heroicons 2.2.0 outline paths copied into `IconsHelper::ICONS`, with
    the file name in a comment; the npm package was checked against the
    registry's sha512 first; the MIT licence is in
    `vendor/heroicons/LICENSE` and named in the README;
  - `markdown` and `headset` stay Stopan's own (no counterpart), scaled
    from the 16 px grid;
  - `icon()` draws on the 24 px grid, stroke 2 at 16 px and below, 1.5
    above; call sites keep the app's names;
  - new places: flash messages, timeline lines (assignee, stage,
    unshared, failed email, deleted, restored, folded run), side panel
    title strips, the menu sections (icon on a small sticky in the
    section's colour), the account menu, and buttons (send reply or
    add note, delete ticket, follow, add colleague or Cc, remove, stop
    sharing); `.btn` got a 6 px gap;
  - `test/helpers/icons_helper_test.rb`;
  - checked in the dev browser: Notes and Omarchy, light and dark,
    1440 and 390 px.
- Form fields (specs/ui.md "Form fields", 2026-11-03):
  - one base style for `.field-input`, `.select` and the plain inputs of
    the account pages: 36 px (44 px on phones), hover, focus ring,
    disabled and read-only states; new variables `--field-height`,
    `--field-border-hover`, `--field-bg-readonly`, `--danger-ring`,
    `--field-chevron`;
  - selects drawn with a `data:` chevron; native check boxes and radios
    in the accent colour; stickies use `color-scheme: light`, so empty
    boxes on light paper in the dark theme no longer look filled;
  - `FieldFormBuilder` (default form builder, in `app/helpers/`) adds
    `aria-invalid` and the messages under each field with errors;
    `.field_with_errors` is `display: contents`;
  - file drop zone (`partials/_file_drop`, `setUpDropzone`) in the
    composer and the new ticket form: the real file input stays, files
    are listed with size and a remove button, plain input without
    JavaScript;
  - leading icons (`input_icon`) on search, Cc email and share link
    fields, never on passwords; joined groups for "Add a colleague",
    the Cc email and the share link (sharing.md, followers.md);
  - `test/integration/form_fields_test.rb` (9 tests).
- Deployed fd2638b (icons and form fields), with no migrations and every
  check passed (specs/deploy.md "Update 2026-11-03 (revision fd2638b)").
- Composer: the "Then set status" select sits above the send button in
  one right-hand column (`.composer__send`), both as wide as the wider
  one; full width on phones (specs/timeline.md "Composer").
- Searchable selects (specs/ui.md "Searchable selects"): a native list
  is not fit for many people. `select[data-combobox]` (`combobox_data`
  helper, `setUpCombobox`) becomes a text field with the select's look
  and a list that narrows by name and detail (the requester's email);
  WAI-ARIA combobox; the real select stays hidden, holds the value and
  fires `change`, so the organization list and the auto-submitting
  filters still work; its required check shows on the field. Used for
  the new ticket requester and the queue's assignee and organization
  filters. The width comes from a CSS variable, not the `size`
  attribute, which CSS reads as a list box.
- Copy code (specs/markdown.md "Copy code"): every `.markdown-body pre`
  gets a copy button in its corner from a `<template data-code-copy>` in
  the layout (`setUpCodeCopy`, also after a Turbo frame load and a cache
  restore). It copies the block's text without the last line break,
  shows a check mark and "Copied", stays put while the block scrolls,
  and is skipped by the message's copy box. Stored and sanitized HTML
  are unchanged.
- Wordmark (specs/ui.md "Logo"): the middle of three lettering styles
  (bold angular capitals, octagonal O with a diamond) traced from the
  drawing into `app/assets/images/stopan-wordmark.svg`: one even-odd
  path, 10 contours, about 1 KB, `currentColor`. Traced with a small
  script (PNG decode, marching squares at the 50 % ink level,
  Ramer-Douglas-Peucker at 0.9 px), since no tracing tool is installed.
  `ApplicationHelper#wordmark` inlines it in the menu bar, 14 px high,
  in place of "Stopan"; checked in Notes light and dark and Omarchy
  dark.
- Buttons: every `.btn` except `.btn--small` is as high as the fields
  (36 px, 44 px on phones).
- Deployed fa54a8b (composer layout, searchable selects, code copy,
  wordmark, button heights), with no migrations and every check passed
  (specs/deploy.md "Update 2026-11-03 (revision fa54a8b)").
- Dependabot (specs/ci.md "Dependency updates"): `.github/dependabot.yml`
  for GitHub Actions (one grouped pull request, SHA pins kept, prefix
  `ci(deps)`) and gems (minor and patch grouped, majors alone, at most 5
  open, prefixes `chore(deps)` / `chore(deps-dev)`), weekly on Monday,
  with a cooldown (7 days; gems 3 patch, 7 minor, 30 major). No
  auto-merge: a branch is merged after `make check` passes locally. The
  base image digest stays a manual update. `test/config/github_test.rb`
  checks the config and that every workflow action is pinned to a SHA.
- Pushed; Dependabot alerts turned on in the repository settings.
- Gem security fixes: the first Dependabot alert (crass, CSS sanitizer
  bypass) and its first pull request (sqlite3, bootsnap) led to
  `make audit`, which listed more advisories in indirect gems. Updated
  with `bundle update --conservative` to the fixed patch releases:
  sqlite3 2.10.2, crass 1.0.8, loofah 2.25.3, nokogiri 1.19.7, rack
  3.2.8, rails-html-sanitizer 1.7.2, plus bootsnap 1.26.1 and msgpack
  1.8.7 from the pull request. `make audit` is clean, `make check`
  passes. Rule added to specs/ci.md: security fixes do not wait for the
  weekly run.
- Deployed 6a89f1d (gem security fixes), no migrations; the running app
  reports the new gem versions and every check passed (specs/deploy.md
  "Update 2026-11-03 (revision 6a89f1d)").
- Dependabot security updates turned on in the repository settings,
  next to the alerts: a fix pull request opens as soon as an alert has
  a fixed release, without the cooldown; merged only after `make check`.
- `make check` now runs `lint`, `audit` and `test` (specs/ci.md "Gem
  audit in make check"). `make audit` updates the advisory database
  first; offline it warns and checks against the local copy, and fails
  only when there is no copy. `config/bundler-audit.yml` has an empty
  ignore list; an entry needs a reason and a date. Checked: the lock file
  from fa54a8b fails the audit (exit 1); with the network blocked the
  target warns and still checks.
- Releases (specs/release.md): Semantic Versioning from 0.x, tags
  `vX.Y.Z` on `main`; the tag is the only place the version is kept, so
  a release needs no commit. `make release VERSION=x.y.z` refuses
  without a valid version, without a signed-in `gh`, off `main`, with
  uncommitted tracked changes, when `HEAD` differs from `origin/main`
  or when the tag exists; then runs `make check`, writes the notes with
  `bin/release-notes`, tags, pushes the tag and creates the GitHub
  release. `bin/release-notes` groups Conventional Commits (breaking,
  features, fixes, performance, dependencies, documentation, other),
  leaves out `docs(session|deploy|todo)` and quotes `@name` and `#123`.
  SECURITY.md: the latest release and `main` get fixes.
- Released v0.1.0 with `make release VERSION=0.1.0`: annotated tag on
  0f74129, GitHub release "Stopan v0.1.0" marked latest, notes with 201
  entries since the start of the project. Production runs 6a89f1d; the
  commits since then change only the Makefile, docs, tests, the audit
  config and `bin/release-notes`, so the running app matches v0.1.0.
- 2026-11-04: deployed v0.1.0 from its tag (detached checkout, `make
  deploy`, back to `main`), no migrations, every check passed
  (specs/deploy.md "Update 2026-11-04 (v0.1.0, revision 0f74129)").
  release.md now says how a tag is deployed.
- 2026-11-05, in progress: signed release tags (specs/release.md
  "Signed tags"). SSH signing with a separate ed25519 key, only for
  signing, with a passphrase, held by ssh-agent. `make release` now
  runs `bin/release`, which also refuses when signing is not set up,
  signs the tag with `git tag -s`, verifies it against
  `.github/allowed_signers` and deletes it again if that fails, before
  anything is pushed. test/config/release_test.rb checks the allowed
  signers file and the order sign, verify, push.
- The signing key exists (ed25519, passphrase, held by ssh-agent with
  the keychain). `.github/allowed_signers` has its public key for the
  principal `t0d0r`; the repository git config has `gpg.format ssh`,
  `user.signingkey`, `tag.gpgSign` and the allowed signers path.
  Checked with a local test tag (deleted, never pushed): good signature
  with the repository config and with the relative path a clone would
  use; rejected against a file holding another key. `make release` now
  passes the signing checks. v0.1.0 stays unsigned.
- The audit in `make check` stopped a commit: new advisories in Rails
  8.1.4 (Active Storage file read/write in image analysis and code
  execution in video previews; Action Pack Strong Parameters bypass and
  RemoteIp spoofing; Action View XSS in text helpers; Active Support
  DoS; Action Mailbox replay). Rails updated to 8.1.4.1 with
  `bundle update rails --conservative`; only the Rails gems moved. The
  production image has no ffmpeg, poppler, vips or ImageMagick and the
  variant processor is disabled, which limits the Active Storage
  issues; the Action Pack and Action View fixes apply directly.
  Production still runs Rails 8.1.4 until the next deploy.
- Released v0.1.1 with `make release VERSION=0.1.1`, the first signed
  tag: verified locally before the push, and "Verified" on GitHub once
  the key was added to the account as a signing key (GitHub checks
  tags pushed before that too). The `gh` token got the
  `admin:ssh_signing_key` scope only to add the key; it was removed
  again afterwards.
- 2026-11-06: deployed v0.1.1 (3a4f4c5) from its tag, no migrations;
  the app reports Rails 8.1.4.1 and every check passed (specs/deploy.md
  "Update 2026-11-06 (v0.1.1, revision 3a4f4c5)").
- Signed release files (specs/release.md "Signed release files"): every
  release gets `stopan-X.Y.Z.tar.gz` (`git archive` of the tag) and its
  SSH signature `stopan-X.Y.Z.tar.gz.sig` (namespace `file`), verified
  against `.github/allowed_signers` before upload. The allowed signers
  line now has `namespaces="git,file"`. `bin/release` builds and checks
  the files before it pushes the tag; `bin/release --files` (`make
  release-files VERSION=x.y.z`) attaches them to an existing release.
  The release notes' security note shows the verify command with the
  version. Checked with a dry run: good signature; a changed archive
  and the `git` namespace are rejected. Scorecard's Signed-Releases
  check counts `.sig` files (8 of 10); 10 needs SLSA provenance.
- Attached the signed files to v0.1.0 and v0.1.1 with `make
  release-files`. Checked as a user would: the files downloaded from
  the releases verify against `allowed_signers` from the public
  repository, and their file lists match the tags.
- Scorecard (v5.6.0) after a manual run: 6.2 (from 5.1).
  Signed-Releases 8 ("2 out of the last 2 releases have a total of 2
  signed artifacts"); Pinned-Dependencies, Dependency-Update-Tool and
  Vulnerabilities 10.
- Release build on GitHub Actions with SLSA build provenance
  (specs/release.md "Release build"). `.github/workflows/release.yml`
  runs on a tag push and by hand for an existing tag. It checks the tag
  name, checks out the tag, verifies its signature (v0.1.0 excepted),
  builds `stopan-X.Y.Z.tar.gz` with `git archive`, attests it with
  `actions/attest-build-provenance` v4.2.2 and uploads the archive and
  `stopan-X.Y.Z.tar.gz.intoto.jsonl` (the Sigstore bundle) as the run
  artifact `release-files`. Its permissions are only `contents: read`,
  `id-token: write` and `attestations: write`; it never writes to the
  repository or its releases.
- `bin/release` pushes the signed tag, waits for that run, downloads
  the two files, checks the run's commit and ref, runs `gh attestation
  verify` with the bundle, checks that the unpacked archive is byte for
  byte the local `git archive` of the tag, then signs the archive and
  creates the release with all three files. `bin/release --files`
  (`make release-files`) starts the build by hand for an existing tag
  and attaches the files, or creates the release when it is missing.
  The release notes' security note adds the `gh attestation verify`
  command. Checked locally: actionlint passes; the content check
  accepts the published v0.1.1 archive and rejects v0.1.0 and a changed
  copy.
- The release build ran by hand for v0.1.1 and v0.1.0 through `make
  release-files`. The v0.1.1 run verified the tag's signature; the
  v0.1.0 run skipped it as the one unsigned tag. Both releases now
  carry the archive from the build, its provenance and a new
  signature; v0.1.1 stays the latest. Checked as a user would, from the
  release downloads: `ssh-keygen -Y verify` prints a good signature,
  `gh attestation verify` with `--signer-workflow` passes (SLSA v1
  provenance, GitHub-hosted runner, workflow at `main`, entry in the
  transparency log), the unpacked archives equal `git archive` of the
  tags, and a changed archive is rejected.
- Scorecard (v5.6.0) after a manual run: 6.3 (from 6.2).
  Signed-Releases 10 ("2 out of the last 2 releases have a total of 4
  signed artifacts"); Pinned-Dependencies, Token-Permissions and
  Dangerous-Workflow stay 10.
- SLSA Build Level 3 for the release build (specs/release.md "Release
  build"). The work moved into the reusable workflow
  `.github/workflows/release-build.yml`, which `release.yml` calls
  with the tag. It has two jobs: `build` (only `contents: read`;
  checks the tag name, checks out the tag, verifies its signature,
  builds the archive, hands its SHA-256 on as a job output, uploads
  the artifact `release-archive`) and `provenance` (only `id-token:
  write` and `attestations: write`; checks the tag and that the digest
  is 64 hex digits, attests by digest, uploads the artifact
  `release-provenance`). `bin/release` downloads both artifacts and
  requires the provenance to be signed by `release-build.yml`. The
  release notes name it in the verify command. The pin test allows a
  workflow of this repository called by path. actionlint passes.
- The Level 3 build ran on GitHub for v0.1.1 and v0.1.0 through `make
  release-files`. Both jobs passed with their reduced permissions; the
  provenance job needs no `contents: read`. The v0.1.1 run verified the
  tag's signature; the v0.1.0 run skipped it as the one unsigned tag.
  The archives and their signatures stayed byte for byte the same
  (same SHA-256 as before); only the `.intoto.jsonl` files were
  replaced. Checked from the release downloads: `ssh-keygen -Y verify`
  prints a good signature; `gh attestation verify` with
  `--signer-workflow` naming `release-build.yml` passes (SLSA v1,
  GitHub-hosted runner, caller `release.yml`, source `main` at
  315f9e7), naming `release.yml` now fails; the unpacked archives
  equal `git archive` of the tags; a changed archive is rejected.
- Scorecard after a manual run at 315f9e7: 6.3. Signed-Releases,
  Pinned-Dependencies (the reusable workflow called by path counts as
  pinned), Token-Permissions and Dangerous-Workflow stay 10.
- The release notes of v0.1.1 and v0.1.0 now end with the Security
  Note that `bin/release-notes` writes, with both verify commands
  (`ssh-keygen -Y verify`, `gh attestation verify --signer-workflow`
  naming `release-build.yml`). The v0.1.0 note says that the archive
  is signed but the tag is not. The rest of the notes and the files
  are unchanged; v0.1.1 stays the latest release.
- Production database reset (specs/deploy.md "Database reset
  (2026-11-09)"). The service was stopped, every entry of
  `~stopan/storage` (the database and the upload directories,
  5.9 MB) moved to `~stopan/backups/reset-2026-11-09/` (700, files
  600; `integrity_check` ok), and the service started again on an
  empty database. The seed created `admin` with `ADMIN_PASSWORD`,
  which matches the root-only password file. No organizations or
  tickets; the public checks and g0no pass. The image is still
  v0.1.1.
- Form field follow-ups (specs/ui.md "Form fields" and "Joined
  groups", attachments.md "Limits"). The file drop zone leaves out
  a file over 10 MB and any file past the fifth, and names each one
  in a red `role="alert"` box under the list; the limits
  (`data-max-files`, `data-max-size`) and the messages come from
  `Attachable` and the locales. The values to copy in the Google
  setup wizard and a new API token are joined to their Copy buttons.
  The public request link joins its field, "Copy link" and "Open"
  in one row; in the organization's details panel and on phones the
  field keeps the top row and the two buttons are joined under it.
  `FieldFormBuilder` moved to `app/form_builders/`. Files:
  `application.js` (`setUpDropzone`), `application.css`,
  `_file_drop`, `_copy_field`, `_public_link`, the account page, the
  three locales, `test/integration/form_fields_test.rb`. Checked in
  headless Chrome: the real `setUpDropzone` on the rendered partial
  with real files (10 checks: size, count, duplicates, remove,
  several lines), and screenshots of the joined controls at 1280
  and 390 px.
- The development container was restarted (`make
  docker-dev-restart`). It had run since before the Rails 8.1.4.1
  update, so new `bin/rails` commands in it failed on missing gems;
  the restart installed them, and the server loads
  `app/form_builders`.
- New ticket form and the busy check (specs/tickets.md "Creating").
  On a plain load `/tickets/new` was already idle. When the form came
  back with errors, the requester script selected the requester's only
  organization, which `pageIsBusy` counted as a change. The script now
  makes its own pick the select's starting value
  (`setUpRequesterOrganizations`). Checked in dev with headless Chrome:
  after a failed submit the page is idle, a change by the user makes
  it busy, and putting the value back makes it idle again. The page
  subscribes to no refresh stream today, so this matters once it
  does.
- Deleted tickets under review (specs/tickets.md "Deleting"): the
  mail view, the files and their previews answered 404 for the
  administrator who opened the read-only page. `find_ticket_for_page`
  moved to `ApplicationController`, and `TicketMailsController` and
  `AttachmentsController` use it; everything that changes a ticket
  still uses `find_visible_ticket`. Agents and requesters still get
  404 (test/controllers/ticket_deletion_test.rb). In integration
  tests a request that ends in 404 does not store a new sign-in, so
  the test signs in with a page that loads first.
- Mailbox fetching takes only mail for the organization's
  `mailbox_address` (specs/organization-mail.md "Fetching"):
  `MailboxCheck#search_keys` searches `UNSEEN OR OR TO a CC a HEADER
  Delivered-To a`, for the run and for "Check the mailbox". Other
  mail is neither fetched nor marked seen, so installations that read
  one account under different +addresses no longer take each other's
  mail. The fake IMAP server of test/models/mailbox_check_test.rb
  filters like a server. Not yet tried against a real IMAP server.
- Outlook replies by mail (specs/organization-mail.md "Processing a
  message"): the stored text kept the earlier message, which Outlook
  quotes under a header block (From, Sent, To, Subject) without `>`.
  The detection of that block moved from `TicketsHelper` into
  `MailQuote` (app/models/mail_quote.rb); the ticket page still shows
  such a block as a collapsible earlier message, and
  `MailboxMessage#without_quotes` now cuts replies there too, with the
  rule line before it. A forwarded-message separator and the header
  block right after it are not cut. Tests: English, German and
  Bulgarian Outlook replies; a forward inside a reply; a lone "From:"
  line in the text.
- 2026-11-10: `main` pushed and deployed at 98a5e93 (not a release),
  with no migrations, on the empty database from the reset; every
  check passed (specs/deploy.md "Update 2026-11-10 (revision
  98a5e93)"). Images kept: 98a5e93, 3a4f4c5 (v0.1.1), 0f74129.
- Admin dashboard warning for Google accounts that need reconnecting
  (specs/admin.md "Google accounts that need reconnecting"). Above the
  stat tiles, one line per organization with `mail_auth: google` whose
  connection is `needs_reconnect`, ordered by name, with the account
  and a link to the organization page; a light red band like the
  deleted-ticket banner, `role="status"`. `MailConnection` now tells
  the `[:admin]` stream on commit, and `access_token` tells it after
  marking the connection with `update_columns`, which skips callbacks;
  the live update test fails without that. Files: the dashboard
  controller and view, `mail_connection.rb`, `application.css`, the
  three locales, test/controllers/admin/dashboard_controller_test.rb,
  test/integration/admin_live_updates_test.rb. Checked in dev at 1280
  and 390 px with two temporary connections, removed afterwards.
- Replies by mail keep their headers (specs/organization-mail.md
  "Mail details"). Migration `20261110090000` adds
  `comments.mail_headers` (JSON), filled by `MailboxMessage#reply`
  with the fields and limits of a new ticket's headers. Staff see a
  closed "Mail details" disclosure at the end of such a reply; the
  list of fields is now the partial `tickets/_mail_header_list`,
  shared with the request's "Details". The API gives staff
  `mail_headers` on such comments (specs/api.md). Requesters, shared
  pages and emails get none. Tests in
  test/controllers/mail_headers_test.rb. Checked in dev at 1280 and
  390 px with a temporary reply, deleted afterwards with its event
  and notification; the dev container's database is migrated.
- The Omarchy theme's fonts are bundled (specs/ui.md "Themes").
  Geist 1.8.2 comes from the npm package `geist`, checked against the
  registry's sha512; it is the newest release older than two weeks.
  JetBrains Mono 2.304 comes from the official GitHub release zip,
  sha256 recorded in the spec. The five woff2 files (one Geist
  variable, four JetBrains Mono weights, about 440 KB) are in
  `app/assets/fonts/`, the OFL texts in `vendor/fonts/`, named in the
  README, with `@font-face` rules in `application.css`. The CSP is
  unchanged. Checked in dev with headless Chrome: the Notes look loads
  no font file; the Omarchy look loads all five, and Geist draws
  Cyrillic. The dev server needed a restart to see the new
  `app/assets/fonts` directory. Test: test/config/fonts_test.rb.
- Scorecard after these changes: 5.1 (from 3.8). Pinned-Dependencies,
  License and Security-Policy are now 10; GitHub detects the license as
  BSD 2-Clause. Still 0: Maintained (repository younger than 90 days),
  Code-Review, Branch-Protection, SAST, Dependency-Update-Tool, Fuzzing,
  CII-Best-Practices.
- 2026-11-11: `main` pushed and deployed at b482106 (not a release):
  the dashboard warning, the headers of mail replies and the bundled
  fonts. A `VACUUM INTO` copy of the database came first because of
  the migration `20261110090000`; the migration ran and every check
  passed (specs/deploy.md "Update 2026-11-11 (revision b482106)").
  Images kept: b482106, 98a5e93, 3a4f4c5 (v0.1.1).
- Leaving a ticket (specs/followers.md "Leaving"). A person in Cc sees
  "Leave Cc" on the People panel, with a confirmation, and lands on My
  tickets. Every email sent to someone as a follower or as Cc ends
  with a link to `/leave/<token>`: a page without sign-in that shows
  only the ticket number and one button, so opening the link changes
  nothing. The token is `TicketFollower#generate_token_for(:leave)`,
  bound to the row and without an expiry; it stops working once the
  person is off the ticket. The page speaks the language of the
  person's emails. The event reads "Ivan Petrov left Cc". Files:
  LeaveLinksController and its three views, TicketFollowersController,
  `Ticket#leave!`, the mailer and both email templates, the People
  panel, `follower_sentence`, the three locales.
- Followers in the API (specs/followers.md "In the API", api.md). The
  ticket has `followers` (staff get every row with `added_by` and
  `created_at`, customers only the Cc rows) and `cc_suggestions` for
  staff who may update it. `POST` adds a colleague by `user_id` or a
  Cc by `email`, `DELETE` removes one, or lets a person in Cc leave.
  The panel and the API share `Ticket#add_staff_follower!`;
  `cc_refused` is now `follower_refused`. Tests:
  test/controllers/leave_links_controller_test.rb,
  test/integration/api_followers_test.rb, and a leaving test in
  test/integration/cc_access_test.rb. Checked in dev with headless
  Chrome as a temporary Cc: the panel button, its confirmation, and
  the leave page at 390 px; the temporary user and its rows were
  removed afterwards.
- 2026-11-12: `main` pushed and deployed at 87769cd (not a release),
  with no migrations; every check passed, the new routes included
  (specs/deploy.md "Update 2026-11-12 (revision 87769cd)"). Images
  kept: 87769cd, b482106, 98a5e93.
- CSV export of the reports (specs/reports.md "CSV export").
  `GET /reports.csv?table=...` gives one of the five tables (volume,
  burndown, statuses, organizations, people) for the page's period and
  organization, with a "Download CSV" link under each. UTF-8 with a
  byte order mark, every field quoted, dates as `YYYY-MM-DD`, durations
  in whole seconds. A text cell that a spreadsheet would run as a
  formula gets a leading apostrophe. The encoder is `ReportCsv`
  (app/models/report_csv.rb), so no new gem. `forbidden` now renders
  its HTML page for any request format; a 403 on a `.csv` request
  failed with a missing template. Tests in
  test/controllers/reports_controller_test.rb. Checked in dev at 1280
  and 390 px.
- 2026-11-12: `main` pushed and deployed at 0ae905e (not a release),
  with no migrations; every check passed (specs/deploy.md "Update
  2026-11-12 (revision 0ae905e)"). Images kept: 0ae905e, 87769cd,
  b482106.
- Automatic done (specs/board.md "Automatic done"). The roadmap's
  "auto-close resolved tickets" now means the `pending` ticket, since
  resolved and closed became done. Migration `20261112090000` adds
  `app_settings.auto_done_days` (default 0, off). `AutoDone.run` marks
  pending tickets without activity for that many days done, without an
  actor, hourly before `AutoPostpone` and by `bin/rails
  stopan:close_pending`; the requester gets the usual email of a
  change to Done. The ticket page says "Marked done in N days" when
  that comes before postponing, and such a card has no "Not now"
  stamp. The setting is in the postponing panel of /admin/settings and
  in the settings API. Tests: test/models/auto_done_test.rb and the
  settings controller test. Checked the panel in dev at 1280 and 390
  px.
- 2026-11-12: `main` pushed and deployed at 34f3e79 (not a release),
  after a `VACUUM INTO` copy of the database for the migration
  `20261112090000`; the migration ran, automatic done is off (0), and
  every check passed (specs/deploy.md "Update 2026-11-12 (revision
  34f3e79)"). Images kept: 34f3e79, 0ae905e, 87769cd.
- The requester adds colleagues to Cc (specs/followers.md "The
  requester adds colleagues"). Only the ticket's requester, and only
  among active requesters who are members of the ticket's organization
  (`Ticket#cc_candidates`, `Ticket#add_cc_member!`); no address is
  typed and no account or membership is made. The People panel shows
  the requester a select of names without addresses, also when nobody
  is in Cc yet, and "Remove" on the people they added
  (`TicketPolicy#add_cc?`, `#remove_cc?`). The API takes `user_id`
  from the requester and gives them `cc_candidates`. Tests:
  test/controllers/requester_cc_test.rb. Checked in dev as a temporary
  requester, removed afterwards.
- 2026-11-12: `main` pushed and deployed at c802739 (not a release),
  with no migrations; every check passed (specs/deploy.md "Update
  2026-11-12 (revision c802739)"). Images kept: c802739, 34f3e79,
  0ae905e.
- Durable job queue (specs/notifications.md "Delivery"). Production
  uses Solid Queue 1.7.0 with a second SQLite database,
  `storage/production_queue.sqlite3` (`config/database.yml`,
  `db/queue_schema.rb`), so queued emails survive a restart. It runs
  inside Puma as threads (`solid_queue_mode :async` in
  `config/puma.rb`): the page refreshes are jobs too, and the async
  Action Cable adapter reaches only the process that broadcasts, so
  forked workers would refresh no page. `MailDeliveryJob` retries a
  failed email 5 times; emails to the customer side stay recorded on
  the ticket and are not retried. Finished jobs are not kept.
  `bin/docker-check` now checks the queue through a restart. Tests:
  test/jobs/mail_delivery_job_test.rb. A change made in the browser
  reached an open `/cable` subscription in the production image.
- 2026-11-12: `main` pushed and deployed at 10b393b (not a release),
  after a `VACUUM INTO` copy of the database. On the server the queue
  runs in one process, an email queued from a console was taken, and
  every other check passed (specs/deploy.md "Update 2026-11-12
  (revision 10b393b)"). Images kept: 10b393b, c802739, 34f3e79.
- 2026-11-12: sign-in is limited to 20 attempts per 5 minutes per
  client address, password reset requests to 5 per 10 minutes per
  client address and per address asked for (specs/auth.md "Rate
  limits"). New `Users::SessionsController` and
  `Users::PasswordsController`, routed in `devise_for`; locale key
  `flash.sign_in_too_many`; test/test_helper.rb clears both counters
  before each integration test. Tests:
  test/controllers/sign_in_rate_limit_test.rb.
- 2026-11-12: `main` pushed and deployed at ec72cc5 (not a release),
  without a database copy (no migration, no gem change).
  `TRUSTED_PROXIES` is now set in the production settings file, and
  the sign-in limit was checked to count per visitor (specs/deploy.md
  "Update 2026-11-12 (revision ec72cc5)"). Images kept: ec72cc5,
  10b393b, c802739.
- 2026-11-12: share links may expire (specs/sharing.md "Expiry"):
  "Never" (default), 1, 7 or 30 days in the share form and as
  `expires_in_days` in the API. New column `tickets.share_expires_at`
  (migration 20261112100000). `Ticket#shared?` and `Ticket.shared`
  leave expired links out, so the page, files, channel, lists, admin
  list and API drop them at once; `ShareExpiry.run` on the hourly
  timer (and `stopan:close_pending`) clears them with an internal
  `share_expired` event and refreshes open pages. Automatic customer
  links never expire. Tests: test/models/share_expiry_test.rb and
  additions to the share controller and API tests.
- 2026-11-12: the bottom of the admin dashboard names the running
  software, "Stopan <git describe>, <commit date>" (specs/admin.md
  "Version"). `bin/deploy` writes the two values into `REVISION` in
  the shipped tree (ignored by git); `BuildInfo` reads it at boot and
  the page says "development version" without it. Tests:
  test/models/build_info_test.rb and the dashboard test.
- 2026-11-12: `main` pushed and deployed at d0db217 (not a release),
  after a `VACUUM INTO` copy of the database. The migration ran, the
  app reports version v0.1.1-35-gd0db217, and every other check
  passed (specs/deploy.md "Update 2026-11-12 (revision d0db217)").
  Images kept: d0db217, ec72cc5, 10b393b.
- 2026-11-12: the reports take a custom date range (specs/reports.md
  "Custom range"): `period=custom` with `from` and `to`, whole days,
  at most 1100, drawn by day, week or month by its length. Date
  fields and an Apply button appear on the filter row; dates that are
  no range show the last 30 days with a note. `TicketReport#till` is
  the end of the period (now, or the end of a past last day); the CSV
  links, the file name and the API carry the range. Tests in
  test/models/ticket_report_test.rb and
  test/controllers/reports_controller_test.rb.
- 2026-11-12: share links count their views (specs/sharing.md "Total
  views"): `tickets.share_views` and `share_last_viewed_at` (migration
  20261112110000), counted when the shared page is shown, once per
  browser session within 30 minutes, reset by a new link. Shown in
  the Sharing panel ("Opened 5 times, last ..."), the admin list and
  the ticket JSON. Tests in the share controller and API tests.
- 2026-11-12: `main` pushed and deployed at 97c3f7d (not a release),
  after a `VACUUM INTO` copy of the database. The migration ran and
  every check passed (specs/deploy.md "Update 2026-11-12 (revision
  97c3f7d)"). Images kept: 97c3f7d, d0db217, ec72cc5.
- 2026-11-12: the API describes itself: `GET /api/v1/openapi.json`
  serves an OpenAPI 3.1 document without a token (specs/api.md
  "OpenAPI"), built by `OpenapiDocument` with the enum values from the
  models. test/models/openapi_document_test.rb compares it with the
  routes both ways. Found on the way: the route `PATCH
  /api/v1/memberships/:id` had no action; it now sets the organization
  administrator mark (`membership[admin]`), and memberships in the API
  answers carry `admin`.
- 2026-11-12: webhooks (specs/webhooks.md). An organization has up to
  5; each posts signed JSON (`X-Stopan-Signature`, HMAC-SHA256) on
  `ticket.created` and `reply.created`, never internal notes or email
  addresses. `Webhook.notify` is called by `TicketNotifier` after
  commit; `WebhookDeliveryJob` sends through `WebhookSender`, which
  takes only https URLs, refuses private and loopback addresses and
  connects to the address it checked; 5 tries, switched off after 20
  failures in a row. New table `webhooks` (migration 20261112120000),
  secret encrypted and shown once. Managed by super administrators in
  a panel on the organization page and under `/api/v1` (described in
  the OpenAPI document). Tests: test/models/webhook_test.rb,
  webhook_sender_test.rb, test/jobs/webhook_delivery_job_test.rb,
  test/controllers/admin/webhooks_controller_test.rb, the API test.
- 2026-11-12: mail HTML for replies and inline images
  (specs/organization-mail.md "Replies and inline images"). A reply by
  mail keeps its cleaned HTML (`comments.mail_html`, migration
  20261112130000) and shows the HTML and Text tabs with its own sealed
  frame (`/tickets/:number/comments/:id/mail`). Files from mail keep
  their part's Content-ID in the blob metadata; the frame rewrites
  `cid:` sources to `.../mail/images/:id`, which serves only PNG,
  JPEG, GIF and WebP files of that message, and its policy allows
  images from that path only. The mail view partial takes the record
  and the id of its text pane. Tests:
  test/controllers/reply_mail_view_test.rb and additions to
  mail_html_test.rb. Seen in a browser with a sample reply.
- 2026-11-12: `main` pushed and deployed at d9d7207 (not a release),
  after a `VACUUM INTO` copy of the database. Both migrations ran,
  the OpenAPI document is served (61 operations) and every check
  passed (specs/deploy.md "Update 2026-11-12 (revision d9d7207)").
  Images kept: d9d7207, 97c3f7d, d0db217.
- 2026-11-12: SLA targets (specs/sla.md). First-response and
  resolution times per priority, in minutes in
  `app_settings.sla_targets` (JSON, empty at first, so nothing shows
  until set), entered in hours on /admin/settings. New
  `tickets.first_response_at`, set by the first public staff reply
  and filled by the migration (20261112140000) for existing tickets.
  `Sla` gives each target a state (met, late, overdue, soon, running,
  waiting). Staff see two lines in the Properties panel and a small
  mark before the subject in the queue (triangle overdue, clock due
  soon); pending and postponed tickets do not warn. The ticket JSON
  has `sla` and `first_response_at` for staff, the settings API
  `sla_targets`. Tests: test/models/sla_test.rb,
  first_response_test.rb, test/controllers/sla_pages_test.rb, the API
  test.
- 2026-11-12: browser tests (specs/system-tests.md). `test/system`
  runs five tests in headless Chrome through Capybara and Cuprite
  (test group only, no driver download): sign in and reply, the
  confirm dialog, the report filters, the mail view tabs, a password
  share link. `make test-system` runs them; they are skipped without
  Chrome and are not part of `make check`. The production image is
  now built without the test group too
  (`BUNDLE_WITHOUT="development:test"`), which also drops the lint
  and audit gems from it; `make docker-check` passed with that image.
- 2026-11-12: `main` pushed and deployed at 44e58c9 (not a release),
  after a `VACUUM INTO` copy of the database. The migration ran, the
  image holds no test or lint gems and the app runs without them, and
  every check passed (specs/deploy.md "Update 2026-11-12 (revision
  44e58c9)"). Images kept: 44e58c9, d9d7207, 97c3f7d.
- 2026-11-12: the queue has an "Overdue" view once any SLA target is
  set (specs/sla.md "Overdue view"): `Sla.overdue` is the "overdue"
  state as SQL (not Done, and unanswered past the first-response
  time or New or In progress past the resolution time), and a test
  checks the two agree. `TicketFilter#views` adds the view for staff,
  so the API list and bulk actions take `view=overdue` too.
- 2026-11-12: the reports show kept SLA targets (specs/sla.md "In the
  reports"): a panel under the tiles, when any target is set, with
  the share of first responses and resolutions within target for the
  period (`TicketReport#sla_rows`), by today's targets and
  priorities; `GET /api/v1/reports` has it as `sla`.
- 2026-11-12: `main` pushed and deployed at 19cab54 (not a release),
  without a database copy (no migration, no gem change). Every check
  passed; with no target set the view and the panel do not show
  (specs/deploy.md "Update 2026-11-12 (revision 19cab54)"). Images
  kept: 19cab54, 44e58c9, d9d7207.
- 2026-11-12: Status page (specs/status.md), `/admin/status`, a tab
  for super administrators. Mail in: fetching on or off, each mailbox
  with its last check and error, and a log of the last 50 messages
  with what became of each (`mailbox_events`, migration
  20261112150000, written by `MailboxMessage#process`; newest 200 per
  organization). Job queue: counts, failed jobs with "Try again" and
  "Discard", recently finished jobs by plain name, never arguments
  (`QueueStatus`, reads Solid Queue's tables in production only).
  Finished jobs are now kept 2 days and cleared hourly. Failing
  webhooks are listed, and the dashboard warns about mailbox errors,
  failed jobs and switched-off webhooks. `bin/docker-check` reads the
  queue through `QueueStatus` in the production image. Symptom that
  led here: production took in one mail and opened no ticket, with no
  way to see why from the app; a mail from a staff member's own
  address is ignored by design.
- 2026-11-12: `main` pushed and deployed at 35cdfbf (not a release),
  after a `VACUUM INTO` copy of the database. Production has its
  first organization with a mailbox; after the deploy the mailbox took
  in four waiting messages, two became tickets and two were skipped
  as automatic, all recorded in the mail log (specs/deploy.md "Update
  2026-11-12 (revision 35cdfbf)"). Images kept: 35cdfbf, 19cab54,
  44e58c9.
- 2026-11-12: the organization form (new and edit) is one wide panel
  with four groups side by side instead of one narrow column about
  three screens tall (specs/ui.md "Organization form"): general and
  mail language, public page, SMTP, IMAP. The page grows to 1560px
  for it; it fits 1280x800 without scrolling and falls to fewer
  columns on narrower windows. `_mail_fields` now holds the SMTP and
  IMAP columns, `_mail_general` the intro and language.
- 2026-11-12: `main` pushed and deployed at 49503f1 (not a release),
  without a database copy (no migration). Checks passed
  (specs/deploy.md "Update 2026-11-12 (revision 49503f1)"). Images
  kept: 49503f1, 35cdfbf, 19cab54.
- 2026-11-12: Shift+click selects a range in check box lists
  (specs/ui.md "Check box lists"): one document-level click handler in
  application.js for boxes that share a name ending in `[]` and a
  form; it fires `change` on each box it sets, so the bulk bar and the
  member picker count along. Browser tests in test/system/bulk_test.rb,
  with two more for bulk delete on the search results. - 2026-11-12: the organization form's columns have set rows instead
  of wrapping ones (specs/ui.md "Organization form"): server and port
  on a row, encryption and TLS on their own, user and password level
  with the password's hint and "remove" box under both, the mailbox
  address and the folder on full rows, the public page's address with
  Copy and Open joined under it. Symptom: after the first version the
  fields were out of place at 1440 and 1280 (Open wrapped under Copy,
  TLS hung beside the port, fields of one row at different heights).
  It fits 1280x900; the earlier note of 1280x800 was wrong. Not
  deployed yet.
- 2026-11-12: several cards move at once on the board (specs/board.md
  "Several cards at once"). Each card has a check box
  (`numbers[]`, form `board-bulk`); ticked cards get a ring, and
  Shift+click ticks a range through the generic handler. Dragging a
  ticked card moves every ticked card, one request each through the
  existing `move` route, with a tag at the pointer; cards that may not
  move there stay and a notice counts them. A bar above the board
  moves the ticked cards without dragging through `PATCH
  /tickets/bulk`, whose `return_to` now accepts the board. Browser
  tests in test/system/board_test.rb.
- 2026-11-12: the member list of an organization's page shows, per
  member, how many tickets they opened in that organization, as a
  link to the queue filtered by requester and organization
  (specs/admin.md "Member's tickets"); zero is plain text. Counted in
  one grouped query in `Admin::OrganizationsController#show`. Not
  Not looked at on a phone.
- 2026-11-12: bulk actions on the Search page did nothing in
  production. Cause: the bulk form posted the page's address in
  `return_to`; with the advanced search fields that address is long
  (`/search?q=&status=&...&created_from=&...`), and ModSecurity in
  Apache answered the request with 403 before it reached the app.
  Shown with signed-out requests through Apache: the long address 403,
  short ones 422 from the app. Fix: no address in the form;
  `TicketBulkController#back_path` takes the path and query of the
  Referer when it is this site's queue, board or search page
  (specs/queues.md "Bulk actions"). The same request without the
  field passes the firewall. It could not be reproduced locally
  because there is no firewall there.
- 2026-11-12: `main` pushed and deployed at 6a2cf43 (not a release),
  without a database copy (no migration). The served script and
  stylesheet carry the changes, and a bulk request in the new shape
  passes the firewall (specs/deploy.md "Update 2026-11-12 (revision
  6a2cf43)"). Images kept: 6a2cf43, 49503f1, 35cdfbf.
- 2026-11-12: the board shows a small preview when the pointer rests
  on a card for half a second, or its subject link has the keyboard
  focus (specs/board.md "Preview on hover"): number, subject, status,
  priority, the first 600 characters of the description, the latest
  message with its author and whether it is an internal note, and
  the counts of replies, notes and files. Fetched on demand from
  `GET /tickets/:number/preview` (staff only, a fragment, no-store,
  plain escaped text) and kept per card until the board reloads. The
  panel never takes the pointer and goes away on leave, Escape,
  scroll, drag, a Move menu or a ticked box. Tests:
  test/controllers/ticket_previews_test.rb and two browser tests.
  Not deployed yet.

## Decisions

- Status page, 2026-11-12: the mail log keeps sender and subject so an
  administrator can recognise a message, for super administrators
  only and cut to 200 per organization; job arguments are never
  shown. Finished jobs are kept 2 days instead of being deleted at
  once, which the page needs to answer "was it sent".

- SLA, 2026-11-12: calendar time and no stopped clock; a pending or
  postponed ticket shows "waiting" instead of a warning, because
  stopping the clock needs a history of pauses. The queue shows an
  icon, not a word, so rows stay one line. Requesters never see
  targets.

- Webhooks, 2026-11-12: public replies and new tickets only, with
  text but without email addresses, so nothing internal or personal
  beyond names leaves; super administrators only, because the text
  goes to another system; the secret is generated, not chosen. No
  delivery log is kept, only the last result.

- Share expiry, 2026-11-12: fixed choices (1, 7, 30 days) instead of
  a date field, and "Never" stays the default, so existing behaviour
  does not change; automatic links in customer emails never expire,
  because sent emails point to them.

- Sign-in limit, 2026-11-12: it runs as a prepended callback, before
  Devise's `require_no_authentication`, which already checks the
  password; with a plain `rate_limit` a blocked attempt with the right
  password was still signed in. The limit (20) stays above the 10
  failed attempts that lock one account.

- Job queue, 2026-11-12: Solid Queue in async mode inside Puma, not
  forked and not a second container, because Action Cable stays on the
  in-process async adapter. Moving to forked workers needs a shared
  cable adapter (Solid Cable) first.

- Followers, 2026-11-12: people outside the organization never go in
  Cc, the share link remains for them; requesters add colleagues to Cc
  only among members of the ticket's organization. Access to tickets
  stays tied to the membership.

- **Provenance from `actions/attest-build-provenance`, not the SLSA
  generator.** The generator must be referenced by a version tag and its
  release is not immutable, so Scorecard's Pinned-Dependencies check
  would count it as unpinned. GitHub's action is pinned by SHA, updated
  by Dependabot, and verified with `gh`.
- **SLSA Build Level 3 as GitHub documents it for attestations:** the
  build and the attestation in a reusable workflow, which signs the
  provenance in its own name. In addition the build job has no
  `id-token` permission, so the steps that build never get the token
  that signs; a separate job signs the digest and runs no project
  code. The reusable workflow stays in this repository: a repository
  of its own would only matter if someone else owned the build.
- **The release build has no write access.** The maintainer's machine
  uploads the files after checking the provenance and the content, so
  the SSH signature means "this archive from GitHub is exactly the
  signed tag".
- **The tag is pushed before its files exist**, since GitHub builds only
  pushed tags. A failure after the push leaves a tag without a release;
  `make release-files` finishes it.

- **Status changes, the opening line and failed emails never fold.** They
  mark the ticket's progress or need attention. Runs fold from 3 lines,
  since one or two lines take no more room than the folded line.

- **Followers come in two kinds, by role.** Staff followers see
  everything. Cc are customers who see the public part only. Mail
  headers suggest Cc addresses but never add them. Follower events are
  internal, so customers and shared pages never see who follows.

- **The email switch is per ticket, not per reply.** It saves at once,
  with no save button, and covers every email to the requester: new
  tickets opened for them, replies and status changes. Staff emails are
  not affected.
- **Only emails to the requester are recorded in the timeline.** They are
  the mail that leaves for the customer.

- **The admin area stays global.** Settings, users, organizations, mail
  and the danger zone still cover every organization. The overview's
  counts stay totals of all tickets: numbers only, no content. Only
  ticket content follows membership.
- **Super administrators keep "Sign in as".** An agent's session shows
  that agent's tickets, so it is still a way to read them. That is
  impersonation as admin.md defines it; it was left unchanged.
- **Super administrators are still never sent to the no-organization
  page**, because they need the admin area. Without memberships their
  queue is empty.

- Deployed 1fa5564 after a backup (`pre-deploy-28361df.sqlite3`); the
  migration ran and every check passed (specs/deploy.md "Update
  2026-11-02 (revision 1fa5564)").

- Deployed 018a5a2 after a backup (`pre-deploy-1fa5564.sqlite3`); both
  migrations ran and every check passed (specs/deploy.md "Update
  2026-11-02 (revision 018a5a2)").

## Open

- Production starts from an empty database: the administrator still
  has the seeded email and the password from the root-only file, and
  organizations, people and the settings in `/admin/settings` have
  to be entered again.
- Form fields: chosen files are lost when the form comes back with
  errors, as before.
- Pinned base images no longer pick up Debian fixes on their own; the
  digest is updated by hand until Dependabot is set up.
- A super administrator who works an organization's tickets adds
  themselves as a member on its page; until then they do not see them.

## Verify

`make test-system` runs the browser tests (needs Chrome; not part of
`make check`).

`make check` (lint, gem audit and tests; the audit needs the network to update its database, else it uses the local copy).

## Next step

Production runs 6a2cf43 (`main` after v0.1.1); it has its first organization, mailbox and tickets.
The changes since v0.1.1 are not in a release yet: the file limits in
the drop zone, the joined copy fields, the new ticket busy fix, the
mail view and files of deleted tickets for administrators, mailbox
fetching by address, Outlook replies, the dashboard warning for Google
accounts that need reconnecting, the headers of mail replies and the
bundled Omarchy fonts, leaving a ticket, followers in the API and the
CSV export of the reports, and automatic done, which stays off until
an administrator sets its days. The mailbox
filter meets a real IMAP server once a mailbox is set up again after
the reset. The followers work is complete and deployed, the requester adding
colleagues to Cc included. The durable job queue is deployed and checked on the
server. A live page refresh through the queue was checked in the
production image locally, not on the server, where the database has
no data yet. The sign-in and password reset rate limits are deployed
and count per visitor. Share link expiry and the version line on the
admin dashboard are deployed; the dashboard line itself is still to be
looked at in production after signing in. The custom range of the
reports and the view count of share links are deployed; the view
count meets a real link once production has tickets. The OpenAPI
description, the webhooks and the HTML of mail replies are deployed. The SLA targets are deployed
and empty, so nothing shows until an administrator sets them; the
image is built without the test group. The "Overdue" view of the
queue and the SLA panel of the reports are deployed and show once a
target is set. The Status page is deployed and its
mail log holds the first real messages. The four-column organization
form, Shift+click ranges, several cards on the board, the members'
ticket links and the bulk actions past the firewall are deployed;
the last four are still to be tried signed in on the server. A webhook has
not met a real receiver yet: delivery is tested against a local
server only. The
other open todo items are larger or need the operator, and the
operator steps after the reset remain.

## Security Note

Ticket content now reaches only members of the ticket's organization,
whatever the role. Impersonation remains the deliberate exception for
super administrators, and it is logged.
