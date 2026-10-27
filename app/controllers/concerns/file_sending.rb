# Sends an Active Storage blob as a download, or inline for the preview
# dialog (specs/attachments.md).
module FileSending
  private

  # Inline only for Attachable::PREVIEW_KINDS; anything else is 404. The
  # sandbox keeps a file opened directly from running as a page of the app;
  # Chrome refuses to show PDFs in one, so PDFs rely on the allow-list and
  # nosniff, and may be framed by the app's own preview dialog.
  def send_blob_preview(blob)
    kind = Attachable.preview_kind(blob)
    return head(:not_found) unless kind

    response.headers["Content-Security-Policy"] =
      kind == "pdf" ? "default-src 'none'; frame-ancestors 'self'" : "default-src 'none'; sandbox"
    send_blob(blob, disposition: "inline", type: (kind == "text" ? "text/plain; charset=utf-8" : blob.content_type))
  end

  # The Disk service has a file on disk, which Rack sends in chunks (and a
  # proxy can take over with X-Sendfile); other services are downloaded.
  def send_blob(blob, disposition: "attachment", type: blob.content_type)
    options = { filename: blob.filename.to_s, type: type, disposition: disposition }
    if blob.service.respond_to?(:path_for)
      send_file blob.service.path_for(blob.key), **options
    else
      send_data blob.download, **options
    end
  end
end
