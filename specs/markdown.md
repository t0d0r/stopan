# Markdown in messages

Requested by the operator on 2026-10-27 as item 2 of the plan "apply
g0no's note display options" (g0no specs/markdown.md). A request, a reply
or a note can be written in Markdown and is then shown formatted.

## Switch

- Columns `tickets.markdown` and `comments.markdown` (boolean, not null,
  default false), per message: each message keeps its own setting, for
  everyone who sees it, on shared pages and in emails.
- **When writing:** a "Markdown" check box under the text area of the
  composer and of the new ticket form, with a one-line hint ("**bold**,
  *italic*, - lists, `code`, [link](https://...)"). Unchecked by default.
- **Later:** an "M" box in the message's title strip (g0no's M-down icon)
  toggles it, for users who may edit the message (timeline.md "Editing";
  `TicketPolicy#edit_description?` / `#edit_comment?`). It is dark while
  on (`aria-pressed`). Routes: `PATCH /tickets/:number/description/markdown`
  and `PATCH /tickets/:number/comments/:id/markdown` with `markdown` "1" or
  "0", then back to the message on the ticket page. Without JavaScript it
  is a small form button. Turbo drops the `#anchor` of a redirect, so for
  Turbo requests the server redirects to the bare ticket page, which Turbo
  renders as a refresh that keeps the scroll position; the same applies to
  saving an edit (timeline.md "Editing").
- The switch is not a text edit: it keeps no revision, does not mark the
  message as edited and is not activity (no event, email or `updated_at`
  change). Open pages refresh live as after an edit.

## Display

- A Markdown message's text is rendered as HTML in `.ticket-text
  .markdown-body` instead of paragraphs with line breaks. The edit form
  always shows the plain text. Earlier versions (timeline.md "Editing")
  stay plain text.
- Formatted text uses the page font; headings are scaled down (a message
  is not a page), code and tables get a light grey background and rules,
  quotes a left rule. Long code lines scroll inside their block.
- Copy box: copies the text as shown (formatted, without Markdown syntax).
- Task list items (`- [ ]`, `- [x]`) are shown as disabled check boxes in
  this phase (clickable later, plan item 6).

## Emails

The HTML part of a notification renders Markdown messages the same way;
the text part keeps the plain text as written.

## Rendering

`MarkdownHelper#render_markdown`, taken from g0no: the `commonmarker` gem
(GitHub flavoured: tables, task lists, strikethrough, autolinks; line
breaks kept; no heading anchors, footnotes or syntax highlighting). It
ships precompiled native gems for macOS and Linux, so the Docker build
needs no compiler.

Safety, in three layers:

1. the renderer omits raw HTML and unsafe link schemes (`render.unsafe`
   off);
2. Rails `sanitize` with an allow-list of tags (headings, paragraphs,
   lists, emphasis, code, quotes, tables, links, check boxes) and
   attributes (`href`, `type`, `checked`, `disabled`, `align`, `start`);
3. links get `rel="noopener noreferrer nofollow"` and `target="_blank"`;
   empty `href`s are removed; only check box inputs survive, always
   disabled.

Images are not allowed, so a message cannot load content from other sites
(no tracking pixels in a ticket or its emails).

## Acceptance

`test/helpers/markdown_helper_test.rb` (formatting, raw HTML and scripts
dropped, `javascript:` links removed, images dropped, link attributes,
disabled check boxes) and `test/controllers/markdown_test.rb` (the check
box on create, the switch per role, no revision or edited marker, plain
messages unchanged, formatted on shared pages and in the HTML email,
plain in the text email).

## Security Note

Markdown output comes from user text, including text from customers. Keep
all three layers if the renderer or its options change, and never allow
`img`, `iframe`, `style`, `form` or event attributes.
