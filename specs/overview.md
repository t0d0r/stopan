# Overview

Stopan is a service desk. Customers ("requesters") belong to organizations
and open tickets; support staff ("agents") triage, answer and resolve them;
administrators manage users, organizations and who is an agent. Every
change to a ticket is recorded in its timeline, and requesters only ever see
their own tickets and the public part of each timeline.

The name comes from the Bulgarian "stopanin" - the one who looks after the
house.

## Origin

Stopan started on 2026-10-25 as a copy of g0no, a Rails 8.1 notes app with a
macOS Stickies look. The copy is deliberately isolated: g0no stays a notes
app in its own repository and is never changed from here. Stopan keeps the
technical baseline (Rails, SQLite, Devise, Turbo Drive, plain CSS and JS, the
Bulgarian/English UI, the light/dark theme and text sizes, the Stickies
visual language) and drops the notes domain completely: notes, tags,
expenses, note history, share links, live note updates, the CouchDB import
and g0no's server deployment files. They remain in git history only.

## Stack

| part | choice |
|------|--------|
| language | Ruby 4.0 |
| framework | Rails 8.1 |
| database | SQLite (storage/<env>.sqlite3) via Active Record |
| files | Active Storage, Disk service, served only through authorized controllers |
| auth | Devise 5 (see auth.md) |
| authorization | plain Ruby policy objects in `app/policies` (see roles.md) |
| assets | Propshaft, one plain CSS file and one plain JS file, no build step |
| page changes | Turbo Drive (no Frames, no Stimulus) |
| server | Puma behind Thruster (in the Docker image) |
| tests | Minitest (`make test`) |
| lint | rubocop-rails-omakase, Brakeman and a gitleaks secret scan of the git history and staged changes (`make lint`; the scan is skipped with a warning when gitleaks is missing) |
| secrets | `make hooks` sets `core.hooksPath` to `.githooks` in this repository; its `pre-commit` runs gitleaks on the staged changes and refuses the commit on a finding, or when gitleaks is not installed |

## Decisions (2026-10-25)

- **Fresh migration baseline.** Stopan has no deployed data, so the g0no
  migrations (including the 2011 users migration and the legacy Devise
  pepper support) were replaced by a new set of migrations that create only
  Stopan's tables. Reason: carrying note tables and a drop migration would
  leave dead history in every new database.
- **Roles as one column.** `users.role` is `requester`, `agent` or `admin`
  instead of g0no's `admin` boolean. A user has exactly one role; an admin
  can do everything an agent can. Reason: three fixed roles are enough for
  this phase and a single column is easy to check and to index. Finer
  permissions (groups, custom roles) are on the roadmap.
- **Agents see all organizations.** Stopan is one service desk serving many
  customer organizations; agents are not restricted per organization in
  this phase (roadmap: agent groups). Requesters are restricted to their own
  tickets inside organizations they belong to.
- **Hand-written policies, no new gem.** Authorization is a small set of
  Ruby classes with tests, so every boundary is visible in one place and no
  dependency is added.
- **404 for tickets you may not see.** A ticket outside your scope answers
  "not found", never "forbidden", so ticket numbers of other customers are
  not confirmed.
- **Timeline as an append-only event log.** Comments and property changes
  are written as `ticket_events` rows that are never updated or deleted.
  Each row carries an `internal` flag, and the requester's view filters on
  it in the database query. See timeline.md.
- **Plain text bodies.** Ticket descriptions and comments are plain text
  rendered with line breaks and escaped HTML; no Markdown in this phase
  (the commonmarker gem was removed).
- **No live updates yet.** g0no's Action Cable note refresh was removed with
  the notes. Live ticket updates are on the roadmap.

## Not in this phase

Email ingestion and notifications, SLAs, automations and macros, a public
API, external integrations, reporting, customer satisfaction, knowledge
base and real multi-tenancy are out of scope. See roadmap.md.

## Security Note

Requester data is personal data. Ticket text and comments are filtered from
logs (`config/initializers/filter_parameter_logging.rb`), attachments are
served only after the same visibility check as their ticket, and sign-up is
closed in production unless `REGISTRATION_OPEN=true`.
