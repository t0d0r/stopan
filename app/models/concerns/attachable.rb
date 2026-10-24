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
