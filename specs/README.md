# Specs

| file | summary |
|------|---------|
| [overview.md](overview.md) | what Stopan is, its origin as a copy of g0no, the stack and the main decisions |
| [roles.md](roles.md) | requester, agent and administrator; organizations and memberships; permission matrix and how it is enforced |
| [tickets.md](tickets.md) | ticket fields, numbering, statuses, allowed transitions, creating and updating |
| [timeline.md](timeline.md) | public replies, internal notes, the append-only event log and the composer |
| [attachments.md](attachments.md) | file limits, allowed types and authorized download-only serving |
| [queues.md](queues.md) | agent queue views, filters, search, sort, pagination and the requester's "My tickets" |
| [admin.md](admin.md) | admin dashboard, users and roles, organizations and memberships |
| [data-model.md](data-model.md) | tables, columns, indexes and deletion rules |
| [auth.md](auth.md) | Devise setup, lockable, deactivation, sign-up switch, seeded admin, demo data |
| [ui.md](ui.md) | Stickies-based look adapted to a service desk, pages, behaviour, accessibility, translations |
| [docker.md](docker.md) | Docker image, compose file and environment variables |
| [deploy.md](deploy.md) | production on stopan.linuxfan.org: ISPConfig site, rootless Podman, setup, verification, rollback |
| [notifications.md](notifications.md) | email notifications: recipients, which email, visibility rules, language, SMTP settings, delivery |
| [roadmap.md](roadmap.md) | later phases: notifications, ingestion, SLAs, automation, API, reporting, groups, ... |

## Security Note

Specs are committed. Describe credentials and hosts in general terms only.
