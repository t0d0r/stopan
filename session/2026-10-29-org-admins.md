# 2026-10-29 - super and organization administrators

## Done

- New spec `specs/org-admins.md`. Updated: roles.md (roles table, matrix,
  enforcement), admin.md, data-model.md (`memberships.admin`),
  notifications.md (message recipients), ui.md (account menu) and the
  specs README.
- The `admin` role is shown as "Super administrator" (en/bg/de). The
  stored value is unchanged.
- An agent becomes an organization administrator through a mark on a
  membership:
  - migration `AddAdminToMemberships`;
  - `Membership` validates that only agents carry the mark;
  - `User` clears the marks when the role changes away from agent;
  - helpers `administered_organizations`, `administers?`, `org_admin?`,
    `admin_area?`.
- `AdminScope` (app/models/admin_scope.rb) decides what an admin user
  reaches. It covers organizations, the users list, manageable users,
  addable users, removable memberships and deleted tickets. Every admin
  controller finds records through it, so anything outside the scope is
  a 404.
- `Admin::BaseController`:
  - `require_admin_area` keeps out everyone who is neither kind of
    administrator;
  - `require_super_admin` covers the settings, stages, Google wizard,
    impersonation, new and deleted organizations, and setting the mark;
  - an organization administrator sent away from those pages lands on
    their organization, or on the list when they administer several.
- Organization page:
  - a shield icon button toggles the mark (`aria-pressed`), for super
    administrators only;
  - an "Organization admin" pill marks the member;
  - Remove is hidden and refused for the reader's own membership, for
    other organization administrators and for super administrators;
  - the Delete button is shown to super administrators only.
- Users list for organization administrators:
  - only members of their organizations;
  - the organizations column names only their own organizations;
  - edit and delete only for the users they manage;
  - roles up to agent;
  - organizations chosen from their own, at least one;
  - no impersonation panel.
- Messages are limited to the members of administered organizations
  (`AdminMessage`, `Admin::MessagesHelper`).
- Deleted tickets: org admins see the list, the read-only page and
  restore only for their organizations (`TicketPolicy#restore?`,
  `TicketsController#find_ticket_for_page`).
- `AdminChannel` and `live_admin_page?` accept both kinds of
  administrator. The signal carries no data.
- Tests:
  - `test/models/membership_test.rb`;
  - `test/controllers/admin/org_admins_test.rb`.
  - `make check` passes with 516 runs.
- Checked in the browser on dev: the organization page and the users
  list as an organization administrator, and the organization page as a
  super administrator.

## Decisions

- **The organization administrator is a mark on the membership, not a
  fourth role.** The mark is per organization, and the user stays an
  agent everywhere else.
- **Only super administrators set the mark**, so an organization
  administrator cannot spread their rights.
- **Organization administrators may:**
  - change their organization's settings and mail;
  - manage its members and accounts up to agent;
  - message its members;
  - use the danger zone;
  - review its deleted tickets.
- **Kept for super administrators:**
  - the overview, settings and Google wizard;
  - creating and deleting organizations;
  - impersonation.

## Open

- Deploy to production; the migration `AddAdminToMemberships` runs. Then
  mark the first organization administrators on the organization pages.

## Verify

`make check`. In the dev container: `bin/rails db:migrate`, mark an
agent's membership, then sign in as that agent and open the account
menu's "Admin".

## Next step

Deploy to production when requested.

## Security Note

Every limit runs on the server through `AdminScope`, so records outside
an organization administrator's organizations are 404s. Mail passwords
stay write-only. Impersonation and the settings of the whole service desk
remain with super administrators.
