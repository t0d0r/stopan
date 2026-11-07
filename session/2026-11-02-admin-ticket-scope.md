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
  copy. Not yet run on GitHub, since the workflow is not on `main` yet.
- Scorecard after these changes: 5.1 (from 3.8). Pinned-Dependencies,
  License and Security-Policy are now 10; GitHub detects the license as
  BSD 2-Clause. Still 0: Maintained (repository younger than 90 days),
  Code-Review, Branch-Protection, SAST, Dependency-Update-Tool, Fuzzing,
  CII-Best-Practices.

## Decisions

- **Provenance from `actions/attest-build-provenance`, not the SLSA
  generator.** The generator must be referenced by a version tag and its
  release is not immutable, so Scorecard's Pinned-Dependencies check
  would count it as unpinned. GitHub's action is pinned by SHA, updated
  by Dependabot, and verified with `gh`. It gives SLSA Build Level 2;
  Level 3 (a reusable build workflow) is left for later.
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

- The release build has not run on GitHub yet. v0.1.0 and v0.1.1 still
  carry the locally built archive and signature; `make release-files`
  replaces them with the build's archive, its provenance and a new
  signature (same files, new checksums). Scorecard's Signed-Releases
  check stays at 8 until then.
- Form fields: the file count and size limits are checked only on the server, and chosen
  files are lost when the form comes back with errors, as before.
- Pinned base images no longer pick up Debian fixes on their own; the
  digest is updated by hand until Dependabot is set up.
- A super administrator who works an organization's tickets adds
  themselves as a member on its page; until then they do not see them.

## Verify

`make check` (lint, gem audit and tests; the audit needs the network to update its database, else it uses the local copy).

## Next step

Push the release build, then `make release-files VERSION=0.1.0` and
`VERSION=0.1.1`; check both downloads with the two verify commands in
specs/release.md and rerun Scorecard. Other open items: the form field
items and the follower items in todo.

## Security Note

Ticket content now reaches only members of the ticket's organization,
whatever the role. Impersonation remains the deliberate exception for
super administrators, and it is logged.
