# 2026-10-25 - service desk phase 1

## Done

- Inspected the inherited g0no baseline (Rails 8.1.4, Ruby 4.0, SQLite,
  Devise 5, Turbo Drive, plain CSS/JS, Stickies UI, bg/en). Baseline `make
  check` passed (119 tests) before any change.
- Wrote the Stopan service desk spec: overview, roles, tickets, timeline,
  attachments, queues, admin, data model, auth, UI, roadmap. Removed the
  note-only specs (features, history, markdown, sharing, live updates,
  CouchDB import, deploy).
- Moved g0no's session notes to `session/g0no/` and archived g0no's todo
  list under "Archive - g0no baseline" in `todo/todo.md`.

## Decisions

See specs/overview.md "Decisions". In short: fresh migration baseline,
`users.role` (requester/agent/admin), agents see all organizations,
hand-written policies, 404 for invisible tickets, append-only
`ticket_events` with an `internal` flag, plain text bodies, no live
updates yet.

## Environment notes

- The shell's default `ruby` is the macOS system Ruby 2.6. Put Homebrew's
  Ruby 4.0 first: `export PATH=/opt/homebrew/opt/ruby/bin:$PATH` (fish:
  `fish_add_path /opt/homebrew/opt/ruby/bin` for the session).
- `vendor/bundle` was cloned from g0no's installed gems (read-only copy) so
  no network was needed.
- `.env` in the project was copied from g0no with the rest of the tree; it
  is ignored by git but holds g0no's secrets. Regenerate it (todo).

## Open

- Nothing blocking yet.

## Files touched

specs/*, todo/todo.md, session/ (this note, `session/g0no/`).

## How to verify

`make check` (rubocop, brakeman, tests). `make run` then sign in as the
seeded admin.

## Next step

Rebrand and remove the notes domain, then the fresh migrations and models.
