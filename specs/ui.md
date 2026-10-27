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
  "Board" (staff, purple; board.md), "New ticket" (green), "Reports"
  (staff, blue; reports.md), "Admin" (admins, grey). The current section
  has `aria-current="page"`: "Queue" on the list and the ticket pages,
  "Board" on the board (operator, 2026-10-27: "a separate button for the
  board in the header"; before, the board counted as "Queue"). Then the ticket search field (signed-in users,
  queues.md "Search"; on its own full-width row under 1180px, where the
  bar wraps instead of running off the screen). Under 560px the bar has
  three rows: the icon with the tools on the right, the section pills on
  a full-width row (wrapping), the search. Right: the
  notification bell with its unread count and panel (notifications.md
  "Notification panel"), theme switch, width switch, three text sizes,
  the language switch (only where it applies, see "Language"), the
  user's name with a role icon (operator,
  2026-10-27: "replace the word administrator / the role with an icon":
  a person for requesters, a headset for agents, a shield for
  administrators; the role's name is its tooltip and its label for screen
  readers), "Logout".
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
  | status postponed | purple |
  | status done | green |
  | priority low / normal / high / urgent | gray / blue / purple / red text with red edge |
  | requester reply | yellow paper |
  | staff public reply | blue paper |
  | internal note | pink paper, padlock, "Internal note" label |

- **Font:** the system font. Ticket numbers use tabular figures.

## Logo

Operator, 2026-10-27: "adopt stopan.png to visual app style, generate
several logos, I will review them". `stopan.png` (repository root) is the
new brand: a teal (`#024146`) circle over a house with a door, and the
word STOPAN under it. Until a candidate is chosen, the app keeps the
yellow sticky icon in `public/icon.svg`.

- The mark is redrawn as vector on a 64-unit grid: circle `cx 32, cy
  17.7, r 8.6`; house `M32 27 56 43.5V55H39.35V43.2L32 38l-7.35
  5.2V55H8V43.5z`.
- Candidates in `docs/logos/`: 1 original (teal, with wordmark), 2 yellow
  sun (head in the yellow strip colour), 3 sticky icon (mark on today's
  yellow sticky), 4 paper house (the house as a yellow sticky, roof as
  title strip), 5 teal tile (mark in paper yellow on a teal tile), 6
  Omarchy (outline mark on a Tokyo Night tile), 7 menu bar lockup (mark
  and STOPAN side by side, ink follows `currentColor`).
- Rules for the chosen logo: it reads at 16 px (tab icon) and 18 px
  (menu bar) on the light and the dark desk; teal ink alone is too dark
  on the dark desk, so a teal mark needs a light ink there (`#d6e9e6`).
  Logos stay static SVG (no scripts, links or external references) and
  are served from the app, as the CSP requires. Wordmark text becomes
  paths before use so it does not depend on the system's fonts.
- Open: which candidate goes where (tab icon, menu bar, Omarchy theme,
  email header).

## Pages

- **Queue** (staff): a coloured row of view tabs, then the filter bar and
  table in a sticky panel in the current view's colour (queues.md). Under
  760px the tab row wraps onto more rows (no sideways scrolling) and
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
  email) and dates. Requesters see "Mark as done" when allowed. Under
  900px the side panel comes after the request note. Shared pages show
  the same note (status pill only) under the read-only notice.
- **Admin:** stat tiles, grey sticky panels with tables, forms in a narrow
  sticky.
- **Account pages:** a small yellow sticky centred on the desk (sign in,
  sign up, password reset).
- **Own account page** (`/users/edit`; operator, 2026-10-27: "the
  personal settings are vertical, make them fit the screen like the
  administration"): a page title "My account" and a grid of sticky
  panels across the desk (as many columns as fit, each at least 320px,
  one column on phones; the panels flow down the columns without gaps),
  each with its caption strip and its own Save:
  Profile (name, email, password; yellow), Language (blue), Theme
  (purple), Order of replies (green), Email notifications (pink, staff
  only), and API tokens (gray, the full width of the grid, api.md). The
  organizations the user belongs to are a line under the grid.
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
- **The request copies the whole ticket** (operator, 2026-10-27: "copy
  should copy all the data of the request, not only the description"):
  the copy box of the original request puts a block of facts before the
  text, one per line as "Label: value" in the reader's language, then an
  empty line and the text. On the ticket page: "#1094 Subject",
  status (and stage, for staff), priority, assignee (or "Unassigned"), requester
  (with the email for staff), organization, created, the ticket's link,
  and for staff the mail's From, To, Cc and Date when the ticket came
  from a mailbox. On a shared page: "#1094 Subject", status and the
  shared link, nothing more than that page shows. Replies and notes copy
  their text only.
- **Emails copy on click** (operator, 2026-10-27: "clicking the
  requester's email should not open the mail program, only copy it"):
  the requester's email in the ticket page's Requester panel and on a
  person's profile is a button that puts the address on the clipboard
  and shows "Copied" next to it for two seconds (also announced to
  screen readers); no `mailto:` link.

## Accessibility

- Works at 390px width with no horizontal page scroll. Navigation (menu
  bar pills, view and section tabs) wraps onto more rows instead of
  scrolling sideways, and the lists people use on phones (queue, My
  tickets, admin users, report tables) hide their less important columns
  under 760px instead (the admin users list shows the email and the role under
  the name), so they do not scroll sideways either (operator, 2026-10-27: "I
  don't like left-right scrolling on mobile"). The board is the one view
  that scrolls sideways by design (board.md).
- Visible focus rings; every field has a label; errors are listed in an
  `role="alert"` box at the top of the form and fields with errors get
  `aria-invalid`.
- Status, priority and internal notes never rely on colour alone.
- Landmarks: `header`, `nav`, `main`, `aside` on the ticket page; one `h1`
  per page; the timeline is an ordered list.
- Respects `prefers-reduced-motion`.

## Translations

The UI is in English, Bulgarian and German (operator, 2026-10-27: "add
German"). All UI text is in `config/locales/{en,bg,de}.yml` (`ui.*`,
`flash.*`, `mailer.*`, `activerecord.*`), Devise text in
`config/locales/devise.{en,bg,de}.yml`, and Rails' own dates, numbers and
validation messages for Bulgarian and German in
`config/locales/rails.{bg,de}.yml`. German uses the formal "Sie".
`test/i18n/locales_test.rb` checks that every language has the same keys
as English.

### Themes

Operator, 2026-10-27: "an option to use themes: two themes, the current
one named notes and a new one named omarchy, style
https://omamobile.org/".

- **Notes** (default): the Stickies look described above.
- **Omarchy**: the look of omamobile.org and the Omarchy desktop: flat
  surfaces with 1px borders and 6px corners, no shadows, a monospace face
  for headings, section pills, buttons, pills, tabs and numbers, and a
  sans-serif body. Colours from Omarchy's palettes: **Tokyo Night** in
  the dark theme (background `#1a1b26`, deep `#14141c`, surfaces
  `#23242f` / `#2a2b35`, borders `#353640` / `#51525a`, text `#c0caf5`,
  muted `#8589a2`, accent `#7aa2f7`) and **Catppuccin Latte** in the
  light theme (background `#eff1f5`, deep `#e5e7eb`, surfaces `#e7e9ec` /
  `#dee0e4`, borders `#d2d4d8` / `#b6b7ba`, text `#4c4f69`, muted
  `#646674`, accent `#1c61e9`). The sun/moon switch keeps choosing light
  or dark in both themes.
- The paper colours keep their meaning (views, statuses, priorities,
  message kinds): in Omarchy each becomes a light tint of the surface in
  that colour of the palette (yellow, blue, green, pink, purple, gray),
  with its title strip a stronger tint, so the colour still tells the
  kind while the page stays flat and dark or light as chosen. Text on
  them uses the theme's text colours.
- Fonts: the CSP allows no font files from other sites, so the theme
  names JetBrains Mono and Geist first and falls back to the system's
  monospace (`ui-monospace`, SF Mono, Menlo, Consolas) and sans-serif
  faces.
- **Site default** (operator, 2026-10-27: "themes configurable for the
  whole site in settings, and users may change them if they want"): an
  administrator picks the theme for everyone on `/admin/settings`
  ("Theme" panel; `app_settings.default_look`, `notes` by default).
- **Own choice:** the account page offers "Site default (Notes)",
  "Notes" and "Omarchy". A choice is kept like the other preferences in
  the `look` cookie (`notes` or `omarchy`, one year, SameSite=Lax) for
  this browser; "Site default" deletes the cookie, so the site's theme
  applies again, including when an administrator changes it later. The
  page renders `<html data-look>` from the cookie, else the site
  default, before any script runs; `PATCH /preferences` with `look`
  (`default` clears it).

### Language

Operator, 2026-10-27: "make it easy to change the language from the
profile or the header". The language of a page is the first of:

1. the signed-in user's chosen language (`users.language`), except while
   an administrator impersonates them (then 2 comes first, so the admin's
   own switch works without changing the user's choice);
2. the `locale` cookie (`en`, `bg` or `de`, one year, SameSite=Lax) set by the
   switch on this browser;
3. the browser's `Accept-Language` (first supported language);
4. English.

- **Header switch:** one group in the menu bar preferences, after the
  text sizes and built like them: the codes of all languages side by
  side ("EN BG DE"), the current one shaded and `aria-pressed="true"`
  (operator, 2026-10-27: separate "EN" and "DE" buttons looked like two
  controls; "they must be one whole"). Any language is one click away;
  each tooltip and label names that language in itself ("English",
  "Български", "Deutsch"), and the group is labelled "Language". The
  buttons are submit buttons of the preferences form (`PATCH /preferences`, `locale=de`), and the
  page reloads in the new language (no script shortcut, unlike theme and
  size). Shown only to visitors who are not signed in (sign-in, password
  and magic link pages, the public request form) and on shared ticket
  pages and their file previews, also when signed in (operator,
  2026-10-27: "when a user is signed in, the language is set only in the
  profile; for the shared link / preview keep it in the header"). Signed
  in (and not impersonating), a click there also saves the choice to the
  user.
- **Account page:** a "Language" section with a select: "Browser
  language" (follow `Accept-Language`; clears the choice and the cookie),
  "English", "Български", "Deutsch", and its own Save button
  (`PATCH /users/language`, like the notification setting; refused while
  impersonating). Saving shows "Language saved." in the new language.
- A chosen language is also the language of the user's emails
  (`users.locale` is set to it, and the browser language no longer
  overwrites it; notifications.md "Content").

## Screenshots

The README shows five screenshots in `docs/screenshots/` (excluded from the
Docker image): the agent queue, the kanban board (`specs/board.md`), the
agent's ticket page, the same ticket for its requester on a 390px phone,
and the admin users list in the dark theme. They use only the fictional
`make demo` data, all in English (operator, 2026-10-27: "English
environment, no Cyrillic in the screenshots"): Chrome runs with
`--lang=en`, `--accept-lang=en` and an English locale environment. Refresh them when one of these pages changes
visibly.

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
