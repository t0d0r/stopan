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
  `aria-current="page"`. Then the ticket search field (signed-in users,
  queues.md "Search"; on its own full-width row under 560px). Right: the
  notification bell with its unread count and panel (notifications.md
  "Notification panel"), theme switch, width switch, three text sizes,
  the user's name with a role label, "Logout".
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

- **Queue** (staff): a coloured row of view tabs, then the filter bar and
  table in a sticky panel in the current view's colour (queues.md). Under
  760px the tab row scrolls sideways and
  table columns other than number, subject and status are hidden.
- **My tickets** (requester): coloured tabs, "New ticket" button, table in
  a sticky panel in the current tab's colour (yellow, green, gray).
- **New ticket:** one yellow sticky form, labels above fields, hints under
  them, required fields marked, file input with the limits stated.
- **Ticket page:** two columns from 900px. Main: the request as one note
  (operator, 2026-10-27: "make this look like one note; the number bold
  before the subject; remove Queue"): the yellow sticky's title strip
  (timeline.md "Message title strip"), then the page's `h1` "**#1001**
  Subject" (number in bold), the status pill, for staff the priority
  pill, and, when someone is assigned, who works on the ticket ("Assigned
  to" with their initials badge and name; operator, 2026-10-27), then the
  text, earlier versions and files. Requesters and shared pages see the
  assignee there too; changes of assignee stay internal events. There is no
  breadcrumb (the menu bar leads back to the queue) and no separate
  "Opened by" line (author and time are in the strip). Then the timeline
  and the composer. Side: "Properties" panel (status, priority,
  assignee as selects with "Update" for staff, plain values for
  requesters; staff also get a one-click "Take" button above the form
  when the ticket is not theirs), "Requester" panel (name, email, organization; staff only see
  email) and dates. Requesters see "Mark as resolved" when allowed. Under
  900px the side panel comes after the request note. Shared pages show
  the same note (status pill only) under the read-only notice.
- **Admin:** stat tiles, grey sticky panels with tables, forms in a narrow
  sticky.
- **Account pages:** a small yellow sticky centred on the desk.
- **Flash messages:** stickies (yellow "Notice", pink "Attention") in a
  band at the top of the desk, under the menu bar and any banner, centred
  and at most 560px wide, on every screen size (operator, 2026-10-27:
  "slide from right to left, stay in the centre, sweep to the left when
  they go"). They slide in from the right edge to the centre (0.5 s), and
  when they go (the close box, or 6 seconds for notices unless hovered or
  focused; alerts stay until closed) they sweep out to the left (0.5 s),
  fully visible until they pass the window's left edge (operator: "let
  them pass the left side"), and the band then closes smoothly, so the
  page below moves up without a jump. The band is as wide as the window
  and clips them at its edges, so the page never scrolls horizontally.
  With reduced motion they appear and disappear without
  movement.
- **Confirm dialog:** a yellow sticky with a red "!" badge, a question, what
  will happen, Cancel and a red action button (`ApplicationHelper#confirm_data`).
- **Forbidden page (403):** a small pink sticky with a sentence and a link
  back to the start page.

## Behaviour (application.js)

- Theme and text-size buttons apply at once and set cookies.
- **Width switch** (plan item 5, from g0no's wide notes; a per-user
  preference instead of per note, since tickets are shared): a box with
  diagonal arrows pointing out (widen) or in (narrow) next to the theme
  switch. Wide lets the desk grow from 1120px to 1920px, so the ticket
  page's main column, the queue table and admin lists use a wide screen;
  narrow forms keep their own width. Kept like theme and text size: the
  `width` cookie (`normal` or `wide`, one year, SameSite=Lax), rendered as
  `<html data-width>` before any script runs, set at once by
  application.js and by `PATCH /preferences` without JavaScript. The
  width changes with a 0.25 s transition (none with reduced motion). The
  box is hidden under 760px, where pages already use the full width.
  Operator, 2026-10-27 ("I don't see the widen button", from g0no where it
  sits on the note): the same box also sits in the title strip of the
  original request, on the ticket page and on shared pages; both boxes
  set the one preference.
- **Shared page width:** one column, 820px in the normal width and the
  full desk width when wide (operator, 2026-10-27: "shared tickets should
  scale properly"); the read-only note, header and messages share that
  column.
- Filter selects in the queue submit their form on change; there is no
  Apply button (only a `<noscript>` one).
- Clearing the menu bar search with the field's clear button submits it.
- The composer switch toggles `is-internal` on the form (pink paper,
  button label "Add internal note" / "Send reply").
- Text areas grow with their text.
- Confirm dialog for `form[data-confirm]`; flash dismissal.
- All page setup runs on `turbo:load`; page listeners use an abort signal.
- **Copy box** (operator, 2026-10-27, from g0no's note window): a small
  copy icon at the right end of the title strip of the request, of every
  reply and note on the ticket page, and of the request and replies on a
  shared page. It puts that message's text on the clipboard as the reader
  sees it (the rendered text's `innerText`, so paragraphs and line breaks
  are kept and Markdown, once added, comes out as text) and shows a green
  check mark for 1.5 seconds (the box's label says "Copied" meanwhile).
  It falls back to `execCommand("copy")` where the Clipboard API is not
  available (plain HTTP other than localhost). It is a `<button hidden>`
  that JavaScript shows, so pages without JavaScript have no dead button.
  Copying reads only what the page already shows; it sends nothing.

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

## Screenshots

The README shows four screenshots in `docs/screenshots/` (excluded from the
Docker image): the agent queue, the agent's ticket page, the same ticket
for its requester on a 390px phone in Bulgarian, and the admin users list
in the dark theme. They use only the fictional `make demo` data.

`make screenshots` refreshes them: start the development server with the
demo data, then run it with `DEMO_PASSWORD` (the password given to `make
demo`) and optionally `STOPAN_URL` (default `http://127.0.0.1:3000`). It
drives headless Chrome over the DevTools protocol (`bin/screenshots`,
Node 22+ for the built-in WebSocket; `CHROME` overrides the binary), warns
on horizontal overflow and compresses with `pngquant` when installed.

## Security Note

User text is always rendered escaped. CSS and JS are served from the app;
a Content Security Policy (`config/initializers/content_security_policy.rb`)
allows only same-origin scripts, styles, images and forms, with a nonce for
Turbo's progress bar style, and forbids framing.
