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
- Deployed 7767fc0 to production with `make deploy` (no migrations, so
  no database copy). Checked: healthy container, `/up` 200, `http://` ->
  301, `/api/v1/me` 401, `/cable` 101, the four security headers, both
  new rules in the served stylesheet, listener only on loopback, g0no
  `/up` 200 (specs/deploy.md "Update 2026-10-28 (revision 7767fc0)").

- App icon: back to the yellow sticky with grey lines and the green check
  mark (`public/icon.svg`, `icon.png`, `apple-touch-icon.png`,
  `favicon.ico` restored from 4cc28fe; `apple-touch-icon-precomposed.png`
  copied from the touch icon again). It reads better at 16 and 18 px than
  the teal mark on the sticky. That logo (`docs/logos/3-sticky-icon.svg`)
  now heads the README only. specs/ui.md "Logo" rewritten.
- A Safari console error "Refused to load data:font/woff2;base64,...
  because it does not appear in the font-src directive" is not from the
  app: no `@font-face`, no `woff2` in the served HTML, CSS or JS. Safari
  applies the page's CSP to fonts that extensions inject, so it is most
  likely an extension. `font-src 'self'` stays; adding `data:` would only
  hide the message.
- Deployed 8e1fe51 (the restored icon) with `make deploy`; the five icon
  files are served byte for byte as in the repository, the other checks
  as for 7767fc0 (specs/deploy.md "Update 2026-10-28 (revision 8e1fe51)").

## Decisions

- Scoped the spacing to the organization panel instead of all
  `.section-title`s, so other panels whose blocks already end with a
  margin do not change.

## Files

app/assets/stylesheets/application.css,
app/views/admin/organizations/show.html.erb, specs/ui.md, todo/todo.md,
session/2026-10-28-org-details.md, README.md, public/{icon.svg,icon.png,
apple-touch-icon.png,apple-touch-icon-precomposed.png,favicon.ico}.

## Verify

`make check`. Open an organization with the public form switched on in
`/admin/organizations`; the development container (`make docker-dev`)
mounts the source, so a reload shows the change. In production it is
live since 7767fc0.

## Next

Look at the organization page in production while signed in as an
administrator; rollback is `localhost/stopan:7767fc0` (specs/deploy.md).

## Security Note

CSS and markup only; no change to what the page shows or who may see it.
