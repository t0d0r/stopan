# Specs

| file | summary |
|------|---------|
| [overview.md](overview.md) | what Stopan is, its origin as a copy of g0no, the stack and the main decisions |
| [roles.md](roles.md) | requester, agent and administrator; organizations and memberships; permission matrix and how it is enforced |
| [tickets.md](tickets.md) | ticket fields, numbering, statuses, allowed transitions, creating and updating |
| [timeline.md](timeline.md) | public replies, internal notes, the append-only event log, editing with earlier versions and the composer |
| [board.md](board.md) | kanban board of tickets by status, Fizzy-like cards, drag and drop |
| [markdown.md](markdown.md) | Markdown per message: switch, sanitized rendering, emails |
| [organization-mail.md](organization-mail.md) | SMTP and IMAP mailbox per organization: settings, outgoing routing, incoming mail to tickets |
| [public-form.md](public-form.md) | public request page per organization, accounts by email, magic sign-in links, abuse limits |
| [attachments.md](attachments.md) | file limits, allowed types, authorized downloads and the preview dialog |
| [queues.md](queues.md) | agent queue views, filters, search, sort, pagination and the requester's "My tickets" |
| [admin.md](admin.md) | admin dashboard, users and roles, organizations and memberships |
| [data-model.md](data-model.md) | tables, columns, indexes and deletion rules |
| [auth.md](auth.md) | Devise setup, lockable, deactivation, sign-up switch, seeded admin, demo data |
| [ui.md](ui.md) | Stickies-based look adapted to a service desk, pages, behaviour, accessibility, translations |
| [docker.md](docker.md) | Docker image, compose file and environment variables |
| [deploy.md](deploy.md) | production on stopan.linuxfan.org: ISPConfig site, rootless Podman, setup, verification, rollback |
| [notifications.md](notifications.md) | email notifications: recipients, which email, visibility rules, language, SMTP settings, delivery |
| [mail-oauth.md](mail-oauth.md) | plan: Google and Microsoft accounts (OAuth 2.0, XOAUTH2) for organization mail |
| [reports.md](reports.md) | statistics page for staff: new, done, backlog, response and resolution times, per organization and person |
| [translation.md](translation.md) | "Translate" button on messages for staff: DeepL, admin switch, stored translations, privacy |
| [sharing.md](sharing.md) | share a ticket by secret link, optionally with a password: who may share, what the public page shows, headers, rate limit |
| [roadmap.md](roadmap.md) | later phases: notifications, ingestion, SLAs, automation, API, reporting, groups, ... |

## Security Note

Specs are committed. Describe credentials and hosts in general terms only.
