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
  message naming the file); nothing is saved.

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

## Acceptance

`test/models/ticket_test.rb` (limits) and
`test/controllers/attachments_controller_test.rb` (visibility, internal note
files, disposition; preview: inline only for previewable kinds, 404
otherwise, the CSP per kind, internal note files not previewable) and
`test/controllers/shared_tickets_controller_test.rb` (shared preview:
public files only, locked links redirect).

## Security Note

Uploaded files are untrusted. Only the allow-listed image, PDF and text
types are ever sent inline, with `nosniff`, and images and text with a
sandboxing `Content-Security-Policy`, so an uploaded file never runs as a
page of the app; SVG and HTML are refused at upload. PDFs are shown by the
browser's own viewer without a sandbox (Chrome refuses one); keep the
browser up to date. Virus scanning is on the roadmap.
