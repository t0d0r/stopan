# Roadmap (later phases)

Deliberately left out of the first phase. Each item needs its own spec
before it is built. The "foundation" column says what already exists.

| area | idea | foundation in phase 1 |
|------|------|-----------------------|
| email notifications | tell requesters about public replies and status changes, agents about assignment | events table records every change; `visible_to` decides what a requester may be told |
| email ingestion | create tickets and replies from inbound mail (Action Mailbox) | `Ticket.create` path and comment creation are model methods, not controller code |
| SMTP | password reset and notifications | Devise mailer sender from `MAILER_SENDER` |
| SLAs | first-response and resolution targets per priority, breach warnings | `priority`, `created_at`, first staff `replied` event, `resolved_at` |
| automation | auto-close resolved tickets after N days, triggers, macros (canned replies) | status transitions in one place (`Ticket::TRANSITIONS`, `Ticket#change_status`) |
| live updates | refresh an open ticket or queue when it changes (Turbo Streams over Action Cable) | Action Cable is still loaded |
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
| attachments | inline image previews (sandboxed), virus scanning | download-only serving, type/size allow-list |
| spam handling | admin deletion of spam tickets with an audit entry | - |
| browser system tests | headless Chrome tests for JS behaviour | flow tests run through Rails integration tests |
| deployment | production hosting for Stopan (container, proxy, TLS, backups) | Dockerfile and compose file |
| security | gitleaks pre-commit hook; rate limit sign-in by IP | Devise lockable per account |

## Security Note

Notifications, ingestion and APIs are the places where internal content
could leak; each must reuse `TicketEvent.visible_to` / `Ticket.visible_to`
rather than build its own filtering.
