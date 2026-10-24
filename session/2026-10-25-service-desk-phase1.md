# 2026-10-25 - service desk phase 1

## Done

- Inspected the inherited g0no baseline (Rails 8.1.4, Ruby 4.0, SQLite,
  Devise 5, Turbo Drive, plain CSS/JS, Stickies UI, bg/en). Baseline `make
  check` passed (119 tests) before any change.
- Wrote the Stopan service desk spec: overview, roles, tickets, timeline,
  attachments, queues, admin, data model, auth, UI, roadmap. Removed the
  note-only specs. Moved g0no's session notes to `session/g0no/` and
  archived g0no's todo list in `todo/todo.md`.
- Rebranded to Stopan (module, layout, icons, Docker image and compose,
  Makefile, `.env.example`, README). Removed the notes domain (models,
  controllers, views, helpers, tests), the CouchDB import, the Markdown gem,
  g0no's deployment files (`deploy/`, `bin/deploy`) and `doc/`.
- Fresh migration baseline: users (role, name, deactivated_at, lockable),
  Active Storage, organizations, memberships, tickets, comments,
  ticket_events.
- Implemented the vertical slice:
  - `Ticket` (numbering from 1001, validations, transition table, status
    timestamps, automatic reopen rules, events written by callbacks),
    `Comment` (public / internal, immutable), `TicketEvent` (append-only,
    `internal` flag), `Attachable` (5 files, 10 MB, type allow-list).
  - `Ticket.visible_to`, `Comment.visible_to`, `TicketEvent.visible_to`
    and `TicketPolicy`; invisible tickets are 404, forbidden actions 403.
  - `TicketFilter` for the agent queue (views with counts, filters, search
    incl. `#number`, sort, pagination) and the requester's "My tickets".
  - Ticket pages: new (requester / staff variants), show with properties,
    requester card, timeline and composer (public reply / internal note
    switch, "then set status"), requester "Mark as resolved".
  - Authorized, download-only attachments (`send_file` for Disk blobs).
  - Admin: dashboard stats, users (roles, memberships, deactivation,
    unassignment on demotion/deactivation, delete only without history),
    organizations and memberships.
  - Devise lockable (10 attempts / 15 min), paranoid mode, password length
    8, deactivation message; own-account page translated, self-deletion
    disabled.
  - Content Security Policy (self only, nonce for Turbo's style), ticket
    text filtered from logs, `ulower()` SQLite function for Unicode
    case-insensitive search.
  - Restyled the Stickies UI for a service desk (queue, pills, timeline,
    composer, panels), all strings in `en.yml` and `bg.yml`; Rails defaults
    moved to `rails.bg.yml` with wrong/Russian messages fixed.
  - `make demo` / `stopan:demo` example data (needs `DEMO_PASSWORD`,
    refuses in production). `make ruby` checks the Ruby version.
- Tests: models, policy, filter, controllers (tickets, comments,
  attachments, admin, authentication, registrations, preferences), seeds,
  locales, and two end-to-end flow tests. `make check`: 122 runs, 505
  assertions, 0 failures; RuboCop clean; Brakeman 0 warnings.
- Checked the UI in headless Chrome (CDP script kept outside the repo) at
  1280px and 390px, light and dark, English and Bulgarian: queue, ticket
  page (staff and requester), new ticket, admin dashboard, users,
  organization, account page. No horizontal overflow at 390px.

## Decisions

See specs/overview.md "Decisions". Added during implementation:

- Events are written by model callbacks (`Ticket#actor`, falling back to
  `Current.user`), so every save path is audited.
- `config.active_storage.touch_attachment_records = false` because comments
  are read-only once saved.
- Users cannot delete their own account; Devise's destroy would have
  failed silently on ticket history.

## Open

- README screenshots not added yet (todo).
- Devise's password reset and sign-up pages: strings exist in bg, but give
  them a full bg pass (todo).
- The Stopan Docker image has not been built (todo, specs/docker.md).
- `.env` copied from g0no still holds g0no's secrets; regenerate (todo).
  Not done by the agent because it overwrites a local secrets file.

## Environment notes

- The shell's default `ruby` is macOS Ruby 2.6. Put Homebrew's Ruby 4.0
  first: `export PATH=/opt/homebrew/opt/ruby/bin:$PATH` (fish:
  `fish_add_path /opt/homebrew/opt/ruby/bin`). `make ruby` says so.
- `vendor/bundle` was cloned from g0no's installed gems (read-only copy).
- `rm` is aliased to interactive mode in the agent's shell; use
  `command rm` with explicit paths.
- A local development database with demo data exists in `storage/`
  (ignored by git).

## Files touched

specs/*, todo/todo.md, session/*, README.md, Makefile, Dockerfile,
compose.yaml, .dockerignore, .env.example, Gemfile(.lock), public icons,
app/** (models, policies, controllers, helpers, views, CSS, JS),
config/** (application, routes, locales, initializers), db/migrate,
db/schema.rb, db/seeds.rb, lib/tasks/demo.rake, test/**.

## How to verify

- `make check` - lint, Brakeman and all tests.
- `make run` - sign in as the seeded admin from `.env`.
- `DEMO_PASSWORD=... make demo` - example organizations, users, tickets.

## Next step

Add README screenshots and a Bulgarian pass over the Devise pages, then
start phase 2 with email notifications (write `specs/notifications.md`
first; reuse `TicketEvent.visible_to` for what requesters are told).
