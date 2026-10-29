# Super administrators and organization administrators

2026-10-29: "a super-admin that controls all of Stopan's settings, and an
organization admin who handles only an organization's changes". The
whole service desk keeps one kind of administrator with full rights. An
organization can also have administrators of its own, who manage that
organization and nothing else.

## Terms

- **Super administrator**: the `admin` role (roles.md). It is renamed in
  the interface only: "Super administrator", "Супер администратор",
  "Super-Administrator". The stored value stays `admin`, so existing
  accounts, tokens and tests keep working. Their rights are unchanged.
- **Organization administrator**: an agent whose membership of an
  organization has the "organization admin" mark
  (`memberships.admin = true`). They "administer" that organization. An
  agent can administer several organizations, and every other
  organization they belong to they work as a plain agent. Labels:
  "Organization admin", "Администратор на организация",
  "Organisationsadministrator".
- Only agents carry the mark. The model rejects it for requesters and
  super administrators. When a user's role changes away from agent,
  every mark of theirs is cleared in the same save.
- A deactivated organization administrator keeps the mark, but cannot
  sign in.

Model helpers:

- `User#administered_organizations`: every organization for super
  administrators, the marked ones for agents, none for requesters.
- `User#administers?(organization)`.
- `User#org_admin?`: an agent with at least one mark.
- `User#admin_area?`: `admin? || org_admin?`.

## Who sets the mark

Only super administrators set the mark, on the organization page. In the
member list, each agent has a shield icon button, pressed
(`aria-pressed`, blue) when the mark is set, named "Make organization
admin" or "Remove organization admin" with the member's name for screen
readers and in its tooltip: `PATCH /admin/memberships/:id` with
`membership[admin]`. A member with the mark has an "Organization admin"
pill beside the role pill, and every viewer of the page sees it.
Organization administrators see the pill but not the button.

**Reason:** an organization administrator promoting other agents would
let a single account spread its rights, so granting stays with the super
administrators.

## What an organization administrator may do

All of these act only on organizations they administer. A record of any
other organization is a 404, so the response never confirms that it
exists.

| area | allowed |
|------|---------|
| Administration link in the account menu | yes, as for super administrators (ui.md "Menu bar") |
| `/admin` start | redirects to the organization when they administer one, otherwise to the organization list |
| organization list | only the administered organizations |
| organization page, edit, update | name, notes, URL name, public form and intro, allowed senders, every mail setting (organization-mail.md) |
| test mail, mailbox check | yes |
| Google / Microsoft account connect and disconnect for the organization (mail-oauth.md) | yes. The OAuth client itself is a Stopan setting, kept for super administrators. |
| add members | users who are active, not super administrators, and who are either members of an organization they administer or members of none (the picker lists exactly these, so other organizations' people stay unseen) |
| remove members | yes, except their own membership, members with the organization admin mark and super administrators |
| users list | users who are members of an administered organization; the organizations column names only the administered ones; the role filter offers requester and agent |
| create a user | role requester or agent; organizations chosen only from the administered ones, at least one |
| edit, delete a user | only a "manageable" user: not themselves, not a super administrator, without any organization admin mark, and every membership in an administered organization. The other rows are listed without edit or delete. Delete keeps the rules of admin.md (no ticket history). |
| role in the user form | requester or agent only |
| messages (notifications.md "Messages from administrators") | to the members of an administered organization, or to one such member; never a whole role or everyone |
| danger zone "Delete all tickets of this organization" | yes, with the same typed confirmation (admin.md) |
| deleted tickets | the list and restore, only for administered organizations; opening such a deleted ticket read-only |
| live refresh of admin pages | yes. The signal carries no data, and the page they fetch again is scoped to them. |

Their tickets are those of an agent: every organization they are a
member of (roles.md). The mark adds nothing to ticket visibility, except
reviewing deleted tickets of administered organizations.

## Kept for super administrators

- The overview (dashboard), the settings (postponing, mailbox polling,
  translation, look, timeline order, stages), and the Google setup
  wizard.
- Creating and deleting organizations, and setting the organization
  admin mark.
- "Sign in as" (impersonation, admin.md), and the impersonation record
  on the user page.
- Roles above agent. Super administrators and organization administrators
  cannot be edited by an organization administrator.
- The admin parts of the API (api.md).

An organization administrator who opens one of these gets a redirect to
the start of the admin area: "Only super administrators can open that
page." Everyone else still gets the existing "Only administrators can
open that page", which redirects to the start page.

The admin tabs show organization administrators only Organizations,
Users and Deleted tickets.

## Data

`memberships.admin` boolean, not null, default false (data-model.md).

## Acceptance

- `test/models/membership_test.rb` and `test/models/user_test.rb`:
  - only agents carry the mark;
  - a role change clears it;
  - `administered_organizations` and `administers?` for each role.
- `test/controllers/admin/org_admins_test.rb`:
  - an organization administrator reaches the pages of their
    organization, and gets 404 for another organization;
  - redirects from the super administrator pages;
  - the users list, create and edit are limited as described;
  - roles above agent are refused;
  - members are added only from the allowed set, and their own and
    marked memberships cannot be removed;
  - messages go only to their organization;
  - deleted tickets are limited to their organizations;
  - only super administrators set the mark.

## Security Note

Every check runs on the server. A hidden button is a convenience. The
scopes (`administered_organizations`, the manageable users, the allowed
members) decide what is found, so an organization administrator who
guesses ids gets a 404 and learns nothing about other organizations. Mail
passwords stay write-only for organization administrators too.
