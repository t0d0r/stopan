# User interface

Stopan keeps g0no's macOS Stickies visual language - pastel paper with a
darker title strip, square corners, a soft shadow, a neutral desk under a
translucent menu bar - and applies it to a working service desk: dense,
scannable lists, a clear ticket timeline and obvious separation of public
and internal content.

Styles: `app/assets/stylesheets/application.css`. Behaviour:
`app/assets/javascripts/application.js`. No CSS framework, no JS framework;
Turbo Drive for page changes.

## Look

- **Desk:** warm grey background (`--desk`), darker in dark mode.
- **Menu bar:** translucent bar at the top. Left: the sticky icon and
  "Stopan" (icon only under 560px), then section pills with a paper-colour
  square: "Queue" (staff, yellow) or "My tickets" (requesters, yellow),
  "New ticket" (green), "Admin" (admins, grey). The current section has
  `aria-current="page"`. Right: theme switch, three text sizes, the user's
  name with a role label, "Logout".
- **Paper colours** (paper / strip), the Stickies set: yellow `#fff6a8 /
  #f5e270`, blue `#cfe7fc / #a9d1f5`, green `#d4f4c6 / #ade5a0`, pink
  `#fcd4e6 / #f4b0cf`, purple `#e3d8fc / #c9b9f5`, gray `#efeeea / #d8d6cf`.
  Paper keeps its colour in dark mode.
- **Meaning of colour** (always paired with text):

  | thing | colour |
  |-------|--------|
  | status new | yellow |
  | status open | pink |
  | status pending | blue |
  | status resolved | green |
  | status closed | gray |
  | priority low / normal / high / urgent | gray / blue / purple / red text with red edge |
  | requester reply | yellow paper |
  | staff public reply | blue paper |
  | internal note | pink paper, padlock, "Internal note" label |

- **Font:** the system font. Ticket numbers use tabular figures.

## Pages

- **Queue** (staff): views column + filter bar + table in a grey sticky
  panel (queues.md). Under 760px the views become a scrollable tab row and
  table columns other than number, subject and status are hidden.
- **My tickets** (requester): tabs, search, "New ticket" button, table in a
  yellow sticky panel.
- **New ticket:** one yellow sticky form, labels above fields, hints under
  them, required fields marked, file input with the limits stated.
- **Ticket page:** two columns from 900px. Main: a header with `#number`,
  subject and status pill; the description as the first sticky; the
  timeline; the composer. Side: "Properties" panel (status, priority,
  assignee as selects with "Update" for staff, plain values for
  requesters), "Requester" panel (name, email, organization; staff only see
  email) and dates. Requesters see "Mark as resolved" when allowed. Under
  900px the side panel comes after the header.
- **Admin:** stat tiles, grey sticky panels with tables, forms in a narrow
  sticky.
- **Account pages:** a small yellow sticky centred on the desk.
- **Flash messages:** small stickies at the top right (yellow "Notice", pink
  "Attention"); notices fade after 6 seconds unless hovered or focused.
- **Confirm dialog:** a yellow sticky with a red "!" badge, a question, what
  will happen, Cancel and a red action button (`ApplicationHelper#confirm_data`).
- **Forbidden page (403):** a small pink sticky with a sentence and a link
  back to the start page.

## Behaviour (application.js)

- Theme and text-size buttons apply at once and set cookies.
- Filter selects in the queue submit their form on change.
- The composer switch toggles `is-internal` on the form (pink paper,
  button label "Add internal note" / "Send reply").
- Text areas grow with their text.
- Confirm dialog for `form[data-confirm]`; flash dismissal.
- All page setup runs on `turbo:load`; page listeners use an abort signal.

## Accessibility

- Works at 390px width with no horizontal page scroll (tables scroll inside
  their panel).
- Visible focus rings; every field has a label; errors are listed in an
  `role="alert"` box at the top of the form and fields with errors get
  `aria-invalid`.
- Status, priority and internal notes never rely on colour alone.
- Landmarks: `header`, `nav`, `main`, `aside` on the ticket page; one `h1`
  per page; the timeline is an ordered list.
- Respects `prefers-reduced-motion`.

## Translations

All UI text is in `config/locales/{en,bg}.yml` (`ui.*`, `flash.*`,
`activerecord.*`) and Devise text in `config/locales/devise.{en,bg}.yml`.
The locale follows the browser's `Accept-Language` (first supported
language, default English). `test/i18n/locales_test.rb` checks that both
files have the same keys.

## Security Note

User text is always rendered escaped. CSS and JS are served from the app;
a Content Security Policy (`config/initializers/content_security_policy.rb`)
allows only same-origin scripts, styles, images and forms, with a nonce for
Turbo's progress bar style, and forbids framing.
