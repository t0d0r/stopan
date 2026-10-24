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
| created_at, updated_at | indexed `updated_at` for the default sort |

Files: `has_many_attached :files`.

## comments

`ticket_id` (FK), `author_id` (FK users), `body` (text), `internal`
(boolean, default false), `created_at`, `updated_at`. Index on
`[ticket_id, created_at]`. Files: `has_many_attached :files`.

## ticket_events

`ticket_id` (FK), `actor_id` (FK users, nullable), `action` (string),
`from_value`, `to_value` (strings), `comment_id` (FK comments, nullable),
`internal` (boolean, default false), `created_at`. Index on
`[ticket_id, created_at]`. No `updated_at`.

## Active Storage

The standard three tables. Blobs are served only by
`AttachmentsController` (attachments.md).

## Deletion rules

- users: `restrict_with_error` on requested tickets, assigned tickets,
  comments and events, so history keeps its people. Memberships are
  deleted with the user.
- organizations: `restrict_with_error` on tickets; memberships deleted.
- tickets, comments, events: not deletable in the app.

## Security Note

The database holds personal data (names, emails, ticket text). Back up and
store `storage/` accordingly; it is ignored by git.
