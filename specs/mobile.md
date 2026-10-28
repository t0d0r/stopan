# Mobile layout rules

Operator, 2026-10-27: "find documentation on UI styles for mobile and
apply it", after "I don't like left-right scrolling on mobile". These
rules hold for every page under 760px (phones), and the parts marked
"everywhere" also on wide screens. ui.md describes the pages; this file
is the checklist they follow on phones.

## Sources

- Apple Human Interface Guidelines: tappable controls at least 44 x 44
  points (secondary summaries:
  [Deque, touch target size](https://dequeuniversity.com/rules/attest-ios/1.0/touch-target-size),
  [Adrian Roselli, Target Size and 2.5.5](https://adrianroselli.com/2019/06/target-size-and-2-5-5.html)).
- Android / Material Design: touch targets at least 48 x 48 dp, about
  9 mm, and 8 dp or more apart
  ([Google, Touch target size](https://support.google.com/accessibility/android/answer/7101858)).
- WCAG 2.2: 2.5.8 Target Size (Minimum, AA) 24 x 24 CSS px or enough
  spacing; 2.5.5 (AAA) 44 x 44
  ([DAISY knowledge base](https://kb.daisy.org/publishing/docs/wcag/target-size-minimum.html),
  [Deque axe target-size](https://dequeuniversity.com/rules/axe/4.8/target-size)).
- iOS Safari zooms into a text field whose rendered font size is below
  16px when it gets focus; disabling zoom in the viewport meta tag is
  not the answer (accessibility)
  ([CSS-Tricks](https://css-tricks.com/16px-or-larger-text-prevents-ios-form-zoom/),
  [Rick Strahl](https://weblog.west-wind.com/posts/2023/Apr/17/Preventing-iOS-Textbox-Auto-Zooming-and-ViewPort-Sizing)).

## Rules

1. **Touch targets of 44 x 44 CSS px** for every control people tap on a
   phone: buttons, selects, text fields, menu bar pills and tools, view
   and section tabs, row actions (icon buttons, "Stop sharing", "Take",
   the assignee menu), composer options. The visible shape may stay
   smaller when padding gives the 44px; neighbours keep at least 8px (or
   a shared 44px row) between them. Inline links inside text are exempt
   (WCAG inline exception).
2. **Text fields at 16px** (inputs, selects, textareas) on phones, so iOS
   does not zoom; the page never sets `maximum-scale` or
   `user-scalable=no`.
3. **No sideways scrolling** (ui.md "Accessibility"): navigation wraps,
   lists hide less important columns or stack their cells, long words
   break. The board is the one intended exception (board.md).
4. **No information only on hover** (everywhere): no `title` tooltips
   carrying content that is not on the page; what matters is in the
   text, an `aria-label` or the next page. Icon buttons keep their
   accessible names.
5. **One column** for forms and side panels; primary actions full width
   where a form ends.
6. **The menu bar does not stay fixed on phones**: with the menu open it
   takes several rows, so it scrolls away with the page instead of
   covering a third of the screen; on wide screens it stays sticky.
7. **The menu behind a button**: the section pills, preferences and
   account sit behind a menu button, so the bar is one row (ui.md "Menu
   bar"). The bar is `position: relative` so the notification panel
   hangs from it above the page.
8. **The ticket page reads first**: side panels closed, the composer
   behind a Reply bar at the bottom of the screen (ui.md "Ticket page on
   phones").
9. **Lists as stacked rows where a table would not fit** (everywhere for
   short admin lists such as the shared links): the title on its own
   line, the details and the action on a second line.

## Checks

A headless Chrome sweep at 360 and 390px over the queue, a ticket, the
board, reports, the admin pages, the account page and the shared page
counts visible controls smaller than 44 x 44 (excluding inline text
links), text fields under 16px, and boxes wider than the screen. It
runs by hand (scratch script), not in `make check`, as there are no
browser tests yet (roadmap.md).

## Security Note

Layout only; nothing here changes what anyone may see. Removing hover
tooltips removes no information: the ticket page shows the full subject.
