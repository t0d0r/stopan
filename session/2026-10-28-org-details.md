# 2026-10-28 - organization details panel

## Done

- Fixed the purple details panel on `/admin/organizations/:id`:
  - The public form's address field (`.public-link .field-input`) had
    `flex: 1; min-width: 0` from `.sharing__link`, so next to the Copy and
    Open buttons in the narrow column it shrank until only "https:" was
    visible. It now has `flex: 1 1 16em`: with room it sits on one row with
    the buttons, in the narrow panel it takes its own full-width row and
    the buttons wrap under it. The same partial on the organization's edit
    form gets the same behaviour.
  - Section titles after the first ("Internal notes", "Public request
    page", "Mail") sat directly under the previous block. The panel now has
    the class `org-details`, and `.org-details .section-title:not(:first-child)`
    adds 18px above them.
- specs/ui.md "Admin" describes both.

## Decisions

- Scoped the spacing to the organization panel instead of all
  `.section-title`s, so other panels whose blocks already end with a
  margin do not change.

## Files

app/assets/stylesheets/application.css,
app/views/admin/organizations/show.html.erb, specs/ui.md, todo/todo.md,
session/2026-10-28-org-details.md.

## Verify

`make check`. Open an organization with the public form switched on in
`/admin/organizations`; the development container (`make docker-dev`)
mounts the source, so a reload shows the change. Production gets it with
the next deploy.

## Next

Deploy with the next production update (specs/deploy.md).

## Security Note

CSS and markup only; no change to what the page shows or who may see it.
