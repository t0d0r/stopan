# SLA targets

2026-11-12, from roadmap.md ("SLAs: first-response and resolution
targets per priority, breach warnings"). Staff see on a ticket and in
the queue when an answer or a solution is due, and when it is late.

## Targets

Two times per priority (low, normal, high, urgent), for the whole
service desk:

- **First response:** from the ticket's creation to the first public
  reply by a staff member.
- **Resolution:** from the ticket's creation to Done.

- Set by super administrators on `/admin/settings`, panel "SLA
  targets": a small table, one row per priority, two fields in hours
  (quarter hours allowed, so 0.25 is 15 minutes; at most 8760). An
  empty field or 0 means no target. **All are empty at first**, so
  nothing shows until an administrator sets one.
- Stored in minutes in `app_settings.sla_targets` (JSON:
  `{"urgent": {"first_response": 60, "resolution": 480}, ...}`).
- Times are calendar time, as in the reports (no business hours).
- A changed target or a changed priority applies at once to open
  tickets, since nothing is stored per ticket but the first response.

## The first response is remembered

`tickets.first_response_at`: set once, when the first public reply by
a staff member is written (the app, email or the API). Internal notes
and replies by the requester do not count. The migration fills it for
existing tickets from their replies. It is never cleared.

## States

`Sla.new(ticket)` gives, for each of the two, nothing (no target), or
the due time and one of:

| state | first response | resolution |
|---|---|---|
| `met` | answered by the due time | done by the due time |
| `late` | answered after it | done after it |
| `overdue` | not answered, due time passed | not done, due time passed |
| `soon` | not answered, less than a fifth of the target left | not done, less than a fifth left |
| `running` | not answered, more time left | not done, more time left |
| `waiting` | - | not done, and the ticket is Pending or Not now |

- A ticket that is Done without any staff reply has no first-response
  state (there is nothing left to answer).
- **Pending and Not now do not warn.** The ticket waits for the
  customer or was put aside on purpose, so the resolution target shows
  as "waiting" without a warning. The clock does not stop: back in New
  or In progress the ticket is measured from its creation again.
  **Reason:** stopping the clock needs a history of every pause;
  this version only keeps the warning honest.

## Where it shows (staff only)

- **Ticket page, Properties panel**, under the fields, when any target
  applies to the ticket's priority: two lines, "First response" and
  "Resolution", each with its state in words: "due in 2 h 10 min",
  "overdue by 3 h", "answered in 35 min" (met), "answered in 5 h, 4 h
  late", "done in 1 d 2 h", "waiting for the customer". Overdue and
  late are marked with a warning icon and a red text, never colour
  alone.
- **Queue**: before the subject, a small mark: a red warning triangle
  when either target is overdue, else a clock when either is due
  soon. Nothing otherwise. Its label and title say which and when
  ("Overdue. First response: overdue by 3 h"), so it is not colour or
  shape alone. An icon, not a word, because the rows stay one line
  (queues.md).
- Requesters, shared pages and emails never show targets.
- **API:** the ticket JSON has `sla` for staff:
  `{first_response: {state, due_at, target_minutes}, resolution:
  {...}}` (each null without a target), and `first_response_at`.
  `GET/PATCH /api/v1/settings` carry `sla_targets` (minutes).

## Not in this version

Business hours and holidays, stopping the clock while Pending,
targets per organization, emails or notifications on a breach, a
queue filter for overdue tickets, SLA numbers in the reports.

## Code

- `Sla` (model without a table) and `Sla::Mark`.
- `AppSetting#sla_targets`, `#sla_minutes(priority, kind)`,
  `#sla_hours=` (the form).
- `Comment` sets `tickets.first_response_at`.
- Helpers `sla_lines(ticket)`, `sla_badge(ticket)`.

## Acceptance

`test/models/sla_test.rb`: every state of both targets on the clock,
no target, Done without a reply, pending waits, a changed priority.
`test/models/first_response_test.rb`: set by the first public staff
reply only, once. `test/controllers/sla_pages_test.rb`: the settings
panel saves hours as minutes and refuses bad values; the lines on the
ticket page and the badge in the queue for staff; nothing for
requesters, on shared pages, or without targets; the API fields.

## Security Note

Targets and their states are for staff only; requesters, shared pages
and emails never carry them, so a missed target is not announced to
the customer. Only super administrators change the targets.
