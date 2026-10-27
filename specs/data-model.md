# Data model

SQLite via Active Record. Schema: `db/schema.rb`. All foreign keys are
declared in the database.

## users (Devise)

| column | notes |
|--------|-------|
| email | unique, required (Devise validatable) |
| encrypted_password | bcrypt |
| username | optional, unique case-insensitively; sign-in accepts email or username |
| name | optional display name |
| role | `requester` (default), `agent`, `admin`; indexed |
| deactivated_at | set = cannot sign in, not assignable |
| locale | nullable, `en`/`bg`: language of the browser last used; emails use it (notifications.md) |
| notify_new_tickets | boolean, default false: staff opt-in to "new ticket" emails (notifications.md) |
| failed_attempts, locked_at | Devise lockable |
| reset_password_*, remember_created_at, trackable columns | Devise |

`User#display_name` = name, else username, else email.

## organizations

| column | notes |
|--------|-------|
| name | required, unique (case-insensitive index on `lower(name)`), at most 120 |
| notes | optional text, staff only |

## memberships

`user_id`, `organization_id`, timestamps. Unique index on the pair.

## tickets

| column | notes |
|--------|-------|
| number | integer, unique index |
| subject | string, required |
| description | text, required |
| status | string, indexed, default `new` |
| priority | string, default `normal` |
| requester_id | FK users, required, indexed |
| assignee_id | FK users, optional, indexed |
| organization_id | FK organizations, required, indexed |
| resolved_at, closed_at | datetime |
| share_token | string, unique index, NULL when not shared (sharing.md) |
| share_password_digest | string, bcrypt, NULL for an open link |
| shared_at | datetime |
| edited_at, edited_by_id | last edit of subject or description (FK users, nullable; timeline.md "Editing") |
| markdown | boolean, default false: the description is Markdown (markdown.md) |
| created_at, updated_at | indexed `updated_at` for the default sort |

Files: `has_many_attached :files`.

## comments

`ticket_id` (FK), `author_id` (FK users), `body` (text), `internal`
(boolean, default false), `created_at`, `updated_at`, `edited_at`,
`edited_by_id` (FK users, nullable), `markdown` (boolean, default false;
markdown.md). Index on `[ticket_id, created_at]`.
Files: `has_many_attached :files`.

## revisions

Earlier versions of edited text (timeline.md "Editing"): `record_type`,
`record_id` (a ticket or a comment), `editor_id` (FK users: who made the
edit that replaced this text), `subject` (tickets only), `body` (the text
before the edit), `created_at` (when the edit was made). Index on
`[record_type, record_id, created_at]`. Only ever inserted.

## ticket_events

`ticket_id` (FK), `actor_id` (FK users, nullable), `action` (string),
`from_value`, `to_value` (strings), `comment_id` (FK comments, nullable),
`internal` (boolean, default false), `created_at`. Index on
`[ticket_id, created_at]`. No `updated_at`.

## notifications

In-app notifications (notifications.md "Notification panel"): `user_id`
(FK, deleted with the user), `ticket_id` (FK), `actor_id` (FK users,
nullable), `kind`, `event_id` (nullable), `status` (nullable), `read_at`,
`created_at`, `updated_at`. Indexes `[user_id, created_at]`,
`[user_id, read_at]`.

## Active Storage

The standard three tables. Blobs are served only by
`AttachmentsController` (attachments.md).

## Deletion rules

- users: `restrict_with_error` on requested tickets, assigned tickets,
  comments, events and revisions they edited, so history keeps its
  people. Memberships are
  deleted with the user.
- organizations: `restrict_with_error` on tickets; memberships deleted.
- tickets, comments, events, revisions: not deletable in the app.

## Security Note

The database holds personal data (names, emails, ticket text). Back up and
store `storage/` accordingly; it is ignored by git.
