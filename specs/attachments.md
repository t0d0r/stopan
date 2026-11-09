# Attachments

Files can be attached when a ticket is created (to the ticket) and to any
reply or internal note (to the comment). Storage is Active Storage
(`has_many_attached :files`), Disk service under `storage/`.

## Limits (server-side validation)

- At most 5 files per ticket or comment.
- At most 10 MB per file.
- Content type, as detected by Active Storage from the file's bytes and
  name, must be in `Attachable::ALLOWED_TYPES`: PNG, JPEG, GIF, WebP, PDF,
  plain text, CSV, JSON, ZIP, and the Office / OpenDocument text,
  spreadsheet and presentation formats. HTML, SVG, scripts and executables
  are refused.
- A refused file makes the whole ticket or comment invalid (422 with a
  message naming the file); nothing is saved, no comment and no blob.
- The file drop zone checks the count and the size in the browser
  too, before sending (ui.md "Form fields"). The server's check stays
  the rule; without JavaScript it is the only one.

## Request size

The limits above are checked only after the whole request has arrived,
and Puma stores a request body (Rack writes multipart files to
temporary files) before Rails sees it. So the web server refuses a body
that is larger than any allowed upload before reading it:

- `MAX_REQUEST_BODY` (bytes), default 54,525,952 (52 MiB): 5 files of
  10 MB plus 2 MiB for the text fields and the multipart framing. It
  applies to every request, signed in or not.
- Puma (`config/puma.rb`, `http_content_length_limit`): a body whose
  `Content-Length` is larger is answered 413 and the connection closed
  before any of it is read; a chunked body is counted while it is read
  and refused when it passes the limit. This covers `bin/rails server`,
  `make run`, the development container and production.
- Thruster, in front of Puma in the image, reads the same variable
  (`ENV MAX_REQUEST_BODY` in the Dockerfile) and answers 413 once a body
  passes it while it is forwarded.
- `0` turns the limit off in both; a value that is not a number, or is
  negative, stops Puma at boot.
- The default must stay at least `MAX_FILES` x `MAX_SIZE` plus 2 MiB;
  `test/config/puma_test.rb` fails otherwise, so changing the
  attachment limits means changing this one too.
- The browser shows the server's plain 413 answer. A body this large
  is far beyond what the forms accept anyway (10 MB per file), and the
  drop zone already keeps the chosen files within the attachment
  limits, so only a form sent without JavaScript can reach it.
- Apache in front of the container must allow at least the same size
  (deploy.md "Request size").

Decision: the limit is in the web server, not in a Rails middleware.
Reason: Puma reads and stores the whole body before the application
runs, so only the server can refuse it unread.

## Serving

- Active Storage's own routes are off (`config.active_storage.draw_routes =
  false`), so blobs have no public URL.
- `GET /tickets/:number/attachments/:id` (`AttachmentsController#show`)
  loads the ticket through `Ticket.visible_to(current_user)`, then looks for
  the attachment among the ticket's own files and the files of comments in
  `Comment.visible_to(current_user)` on that ticket. Anything else is 404.
  So a requester can never download a file from an internal note.
- Files are always sent with `Content-Disposition: attachment`. With the
  Disk service the controller uses `send_file` on the blob's path, so Rack
  sends it in chunks (and a proxy can take over with X-Sendfile) instead of
  loading it into memory; other services fall back to `send_data`.
  `X-Content-Type-Options: nosniff` comes from the Rails defaults.
- Files of a saved comment never change (only its text can be edited), so
  `config.active_storage.touch_attachment_records` is false (attaching a
  file must not touch its record).

## Preview

Requested by the operator on 2026-10-27: files in a format the browser
can show are previewed instead of downloaded. Modelled on g0no's preview
dialog.

Clicking a file name (on the ticket page and on a shared page) opens a
preview dialog: a yellow sticky with the file name in its title strip,
the file below, and a footer with the size, "n / total" and a Download
button. Previous/next boxes and the arrow keys move between all files on
the page, in page order. Escape, the close box or a click on the backdrop
closes it. Ctrl/Cmd/Shift/Alt-click and pages without JavaScript still
download (the link's `href` stays the download URL).

| kind | content types | shown as |
|------|---------------|----------|
| image | png, jpeg, gif, webp | `<img>` |
| pdf | application/pdf | `<iframe>` (the browser's PDF viewer) |
| text | text/plain, text/csv, application/json, up to 1 MB | fetched and shown as text in `<pre>` |

Anything else (office files, archives, text over 1 MB) shows "No preview
for this file type" with the Download button. The kind comes from the
content type Active Storage detected from the file's bytes and name
(`Attachable.preview_kind`), never from the upload's claim.

Routes, with exactly the lookups and checks of their download routes:

| route | for |
|-------|-----|
| `GET /tickets/:number/attachments/:id/preview` | signed-in users who may see the file |
| `GET /s/:token/files/:id/preview` | a shared page (public files only, unlocked password links only) |

- Sent with `Content-Disposition: inline`, only for the kinds above; any
  other file is 404 on these routes. Text kinds are sent as
  `text/plain; charset=utf-8`.
- `Content-Security-Policy: default-src 'none'; sandbox` on images and
  text, so a file opened directly never runs as a page of the app. Chrome
  refuses to show PDFs in a sandbox, so PDFs get `default-src 'none';
  frame-ancestors 'self'` (the app's own policy forbids framing, and the
  dialog frames the PDF) and rely on the allow-list and `nosniff`.
- A live page refresh waits while the dialog is open (an open dialog
  makes the page busy).
- **Image size** (2026-11-02: "the preview shows images far too small").
  - The dialog for an image is as wide as the image needs: its natural
    size, up to the window less a 16px margin on each side. It is never
    narrower than 480px (or the window), so the title strip and the
    footer keep their buttons. The image is scaled down only when it is
    larger than the space left for it (the window's height less the
    strip and the footer).
  - PDFs and text keep the 960px dialog.
  - **Actual size:** an image that had to be scaled down is a button.
    - "Show at actual size" with a zoom-in cursor shows it at its natural
      size, with the dialog's media area scrolling both ways.
    - Pressing it again, "Fit to window", scales it back.
    - `aria-pressed` gives the state.
    - An image that fits is not a button.
  - Moving to another file starts again at fit to window.

## Acceptance

`test/models/ticket_test.rb` (limits) and
`test/controllers/attachments_controller_test.rb` (visibility, internal note
files, disposition; preview: inline only for previewable kinds, 404
otherwise, the CSP per kind, internal note files not previewable) and
`test/controllers/shared_tickets_controller_test.rb` (shared preview:
public files only, locked links redirect) and
`test/integration/api_test.rb` (files on new tickets and on replies and
notes as multipart; a requester's `internal` flag with a file stays a
public reply; a staff note's file is 404 for the requester; a refused
type is 422 `invalid` naming the file and stores no comment and no blob)
and `test/models/mailbox_message_test.rb` (mail attachments) and
`test/config/puma_test.rb` (request size: the default against the
attachment limits, `MAX_REQUEST_BODY` and `0`, the Dockerfile value).

Checked by hand on 2026-10-31 with `bin/rails server` and Thruster on
the local machine: a 1 MiB body reaches the app; 53 MiB with
`Content-Length` and 53 MiB chunked get 413 from Puma, and from
Thruster alone (Puma's limit set to 0 behind it).

## Security Note

Uploaded files are untrusted. Only the allow-listed image, PDF and text
types are ever sent inline, with `nosniff`, and images and text with a
sandboxing `Content-Security-Policy`, so an uploaded file never runs as a
page of the app; SVG and HTML are refused at upload. PDFs are shown by the
browser's own viewer without a sandbox (Chrome refuses one); keep the
browser up to date. Request bodies over `MAX_REQUEST_BODY` are refused
before they are read, so nobody, signed in or not, can make the server
store an arbitrarily large upload in its temporary files. Virus scanning
is on the roadmap.
