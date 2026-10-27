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
- Task list items (`- [ ]`, `- [x]`) are check boxes; see "Task lists".

## Plain text links

Operator, 2026-10-27, with a screenshot of a mail from a newsletter: "the
formatting of the read mail is bad". Mail in plain text often carries
long tracking addresses (hundreds of characters of query string) that
fill the page.

- In a message that is not Markdown (and in organization notes and
  notifications, which use the same plain text rendering), every
  `http://` or `https://` address becomes a link with a short label: the
  host without `www.` and the path, without query string and fragment,
  cut to 48 characters with a trailing ellipsis; for example
  `linkedin.com/comm/in/some-person-123`. The link goes to the full
  address as written, with `rel="noopener noreferrer nofollow"` and
  `target="_blank"` like Markdown links. Trailing punctuation (`.`, `,`,
  `;`, `:`, `!`, `?`, a closing bracket without its opening one) is not
  part of the address.
- Only the label is shortened; the stored text is unchanged, and editing
  shows the full address.
- Copy box: copies the full addresses, not the short labels.
- Emails keep the text as written (their plain text part), with the same
  links in the HTML part.

## Task lists

Plan item 6 (g0no markdown.md "Task lists"): users who may edit a message
can tick its task list items on the ticket page.

- Each check box of an editable message carries `data-task-line`, the
  source line of its list item (from the renderer's source positions, so a
  "- [ ]" inside a code block is never touched). It is rendered disabled
  and application.js enables it, so without JavaScript nothing looks
  clickable. Everyone else, shared pages and emails get disabled boxes
  without a line.
- A click sends `PATCH /tickets/:number/description/task` or
  `PATCH /tickets/:number/comments/:id/task` with `line` and `checked`
  ("1"/"0") through Turbo's `fetch` (so this tab skips its own live
  refresh). The server checks the edit right, flips `[ ]` / `[x]` on that
  line only when the rendered Markdown has a task box on it
  (`MarkdownHelper.task_lines`, so a "- [ ]" in a code block is refused;
  `- [ ]`, `* [x]`, `1. [ ]`, also inside quotes), and saves it as an edit (`Editable#edit`): the message
  is marked as edited and other open pages refresh. It answers 204; 422
  when the line is not a task item, 403/404 as for edits. On an error the
  box flips back.
- **One revision per series:** clicks by the same person on the same
  message less than 10 minutes after their previous edit of it do not add
  another earlier version; the earliest text of the series stays as the
  one earlier version (`edit(group: true)`), so ticking ten items does not
  fill the list with ten versions.

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
   empty `href`s are removed; only check box inputs survive, disabled
   unless they are task boxes of an editable message (above).

Images are not allowed, so a message cannot load content from other sites
(no tracking pixels in a ticket or its emails).

## Acceptance

`test/helpers/markdown_helper_test.rb` (formatting, raw HTML and scripts
dropped, `javascript:` links removed, images dropped, link attributes,
disabled check boxes) and `test/controllers/markdown_test.rb` (the check
box on create, the switch per role, no revision or edited marker, plain
messages unchanged, formatted on shared pages and in the HTML email,
plain in the text email) and `test/controllers/task_list_test.rb` (task
lines only for editors, flipping the right line, code blocks untouched,
422 for other lines, rights, one revision per series).

## Security Note

Markdown output comes from user text, including text from customers. Keep
all three layers if the renderer or its options change, and never allow
`img`, `iframe`, `style`, `form` or event attributes.
