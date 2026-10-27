# Files on tickets and comments, with the limits from specs/attachments.md.
# Content types come from Active Storage, which looks at the file's bytes
# as well as its name.
module Attachable
  extend ActiveSupport::Concern

  MAX_FILES = 5
  MAX_SIZE = 10.megabytes
  ALLOWED_TYPES = %w[
    image/png image/jpeg image/gif image/webp
    application/pdf
    text/plain text/csv application/json
    application/zip
    application/msword application/vnd.ms-excel application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.oasis.opendocument.text
    application/vnd.oasis.opendocument.spreadsheet
    application/vnd.oasis.opendocument.presentation
  ].freeze
  # Only these are ever sent inline, for the preview dialog
  # (specs/attachments.md "Preview").
  PREVIEW_KINDS = {
    "image" => %w[image/png image/jpeg image/gif image/webp],
    "pdf" => %w[application/pdf],
    "text" => %w[text/plain text/csv application/json]
  }.freeze
  TEXT_PREVIEW_LIMIT = 1.megabyte

  # "image", "pdf", "text", or nil when the blob has no preview.
  def self.preview_kind(blob)
    kind = PREVIEW_KINDS.find { |_kind, types| types.include?(blob.content_type) }&.first
    kind unless kind == "text" && blob.byte_size > TEXT_PREVIEW_LIMIT
  end

  included do
    has_many_attached :files
    validate :files_within_limits
  end

  private

  def files_within_limits
    return unless files.attached?

    errors.add(:files, :too_many, count: MAX_FILES) if files.size > MAX_FILES
    files.each do |file|
      name = file.blob.filename.to_s
      errors.add(:files, :too_big, filename: name, limit: MAX_SIZE / 1.megabyte) if file.blob.byte_size > MAX_SIZE
      errors.add(:files, :type_not_allowed, filename: name) unless ALLOWED_TYPES.include?(file.blob.content_type)
    end
  end
end
