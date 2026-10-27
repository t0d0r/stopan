# Roadmap (later phases)

Deliberately left out of the first phase. Each item needs its own spec
before it is built. The "foundation" column says what already exists.

| area | idea | foundation in phase 1 |
|------|------|-----------------------|
| email notifications | **specified in notifications.md (phase 2)**; later: per-user preferences, digests, durable queue (Solid Queue) | events table records every change; `visible_to` decides what a requester may be told |
| email ingestion | **specified in organization-mail.md (IMAP per organization)**; later: OAuth2 for Google / Microsoft 365, POP3, moving processed mail, spam scoring | `Ticket.create` path and comment creation are model methods, not controller code |
| SMTP | **specified in notifications.md (phase 2)** | Devise mailer sender from `MAILER_SENDER` |
| SLAs | first-response and resolution targets per priority, breach warnings | `priority`, `created_at`, first staff `replied` event, `done_at` |
| automation | triggers, macros (canned replies) | status transitions in one place (`Ticket::TRANSITIONS`, `Ticket#change_status`) |
| live updates | later: partial updates (Turbo Stream replace of one row) instead of page refreshes for busy queues | done: notification panel (notifications.md), shared pages (sharing.md), ticket page (timeline.md), ticket lists (queues.md), admin pages (admin.md) |
| API | JSON API with tokens for integrations | policies and scopes are independent of HTML controllers |
| integrations | chat, monitoring alerts, CRM | - |
| reporting | volume, backlog, response and resolution times, agent load | events table |
| agent groups | groups/teams, restrict agents to groups or organizations, group queues | role column; `Ticket.visible_to` is the single place to narrow |
| organization visibility | let selected requesters see all tickets of their organization | membership row can carry a flag |
| CC / followers | more people on one ticket | - |
| tags, custom fields, ticket forms | categorisation | - |
| knowledge base / self-service | articles, suggested answers | - |
| satisfaction survey | CSAT after resolve | - |
| multi-tenancy | several independent service desks in one installation | - |
| attachments | virus scanning, thumbnails | type/size allow-list, preview dialog for images, PDFs and text (attachments.md) |
| sharing | **specified in sharing.md**; later: link expiry dates, total view counts, several links per ticket | public timeline scope (`internal = false`), live count of open pages |
| spam handling | admin deletion of spam tickets with an audit entry | - |
| browser system tests | headless Chrome tests for JS behaviour | flow tests run through Rails integration tests |
| deployment | production hosting for Stopan (container, proxy, TLS, backups) | Dockerfile and compose file |
| security | rate limit sign-in and password reset requests by IP (Rails `rate_limit`). Prerequisite: confirm in production that `request.remote_ip` is the client address behind Apache, pasta and Thruster; if it is a shared proxy address the limit would apply to everyone | Devise lockable per account; gitleaks pre-commit hook (done) |

## Security Note

Notifications, ingestion and APIs are the places where internal content
could leak; each must reuse `TicketEvent.visible_to` / `Ticket.visible_to`
rather than build its own filtering.
