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
  `X-Content-Type-Options: nosniff` comes from the Rails defaults. There is
  no inline preview in this phase.
- Comments are immutable, so `config.active_storage.touch_attachment_records`
  is false (attaching a file must not touch its record).

## Acceptance

`test/models/ticket_test.rb` (limits) and
`test/controllers/attachments_controller_test.rb` (visibility, internal note
files, disposition).

## Security Note

Uploaded files are untrusted. Keep them download-only; if inline previews
are added later, serve them with a sandboxing `Content-Security-Policy`
from an allow-list of safe image types only. Virus scanning is on the
roadmap.
