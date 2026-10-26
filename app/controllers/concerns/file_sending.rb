# Sends an Active Storage blob as a download (specs/attachments.md).
module FileSending
  private

  # The Disk service has a file on disk, which Rack sends in chunks (and a
  # proxy can take over with X-Sendfile); other services are downloaded.
  def send_blob(blob)
    options = { filename: blob.filename.to_s, type: blob.content_type, disposition: "attachment" }
    if blob.service.respond_to?(:path_for)
      send_file blob.service.path_for(blob.key), **options
    else
      send_data blob.download, **options
    end
  end
end
