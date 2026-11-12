# Roadmap (later phases)

Deliberately left out of the first phase. Each item needs its own spec
before it is built. The "foundation" column says what already exists.

| area | idea | foundation in phase 1 |
|------|------|-----------------------|
| email notifications | **specified in notifications.md (phase 2)**; later: per-user preferences, digests; the durable queue (Solid Queue) is done (notifications.md "Delivery") | events table records every change; `visible_to` decides what a requester may be told |
| email ingestion | **specified in organization-mail.md (IMAP per organization)**; OAuth2 for Google / Microsoft 365 planned in mail-oauth.md; later: POP3, moving processed mail, spam scoring | `Ticket.create` path and comment creation are model methods, not controller code |
| SMTP | **specified in notifications.md (phase 2)** | Devise mailer sender from `MAILER_SENDER` |
| SLAs | **done 2026-11-12, sla.md**: first-response and resolution targets per priority, warnings for staff; later: business hours, pausing while pending, breach notifications, reports | `priority`, `created_at`, first staff `replied` event, `done_at` |
| automation | triggers, macros (canned replies) | status transitions in one place (`Ticket::TRANSITIONS`, `Ticket#change_status`) |
| live updates | later: partial updates (Turbo Stream replace of one row) instead of page refreshes for busy queues | done: notification panel (notifications.md), shared pages (sharing.md), ticket page (timeline.md), ticket lists (queues.md), admin pages (admin.md) |
| API | built 2026-10-27, see api.md; OpenAPI description and webhooks (webhooks.md) done 2026-11-12 | - |
| integrations | chat, monitoring alerts, CRM | - |
| reporting | **specified in reports.md**; later: CSV export, custom date ranges, business hours | events table, `done_at`, comments |
| agent groups | groups/teams, restrict agents to groups or organizations, group queues | role column; `Ticket.visible_to` is the single place to narrow |
| organization visibility | let selected requesters see all tickets of their organization | membership row can carry a flag |
| CC / followers | **specified in followers.md**; later: requesters adding Cc, people outside the organization, API | `Ticket.visible_to`, notifier candidates |
| tags, custom fields, ticket forms | categorisation | - |
| knowledge base / self-service | articles, suggested answers | - |
| satisfaction survey | CSAT after resolve | - |
| multi-tenancy | several independent service desks in one installation | - |
| attachments | virus scanning, thumbnails | type/size allow-list, preview dialog for images, PDFs and text (attachments.md) |
| sharing | **specified in sharing.md**; later: several links per ticket; link expiry and total views are done (sharing.md) | public timeline scope (`internal = false`), live count of open pages |
| spam handling | admin deletion of spam tickets with an audit entry | - |
| browser system tests | **done 2026-11-12, system-tests.md** (`make test-system`); uploads and phones added the same day (seven more tests); later: live updates, a real pointer for drag and drop | flow tests run through Rails integration tests |
| deployment | production hosting for Stopan (container, proxy, TLS, backups) | Dockerfile and compose file |
| security | sign-in and password reset requests are rate limited by client address (done, auth.md "Rate limits"); production still needs `TRUSTED_PROXIES` so the limit is per visitor | Devise lockable per account; gitleaks pre-commit hook (done) |

## Security Note

Notifications, ingestion and APIs are the places where internal content
could leak; each must reuse `TicketEvent.visible_to` / `Ticket.visible_to`
rather than build its own filtering.
