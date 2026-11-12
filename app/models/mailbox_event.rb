# What became of one message a mailbox took in, for the Status page
# (specs/status.md "Mail in"). Only the newest KEEP per organization stay.
class MailboxEvent < ApplicationRecord
  RESULTS = %w[ticket reply skipped ignored failed].freeze
  KEEP = 200
  SUBJECT_LIMIT = 150

  belongs_to :organization
  belongs_to :ticket, optional: true

  validates :result, inclusion: { in: RESULTS }

  scope :newest_first, -> { order(id: :desc) }

  # Never raises: the log must not stop mail from being taken in.
  def self.record(organization, result:, reason: nil, sender: nil, subject: nil, ticket: nil)
    create!(organization: organization, result: result.to_s, reason: reason&.to_s&.first(100),
            sender: sender.to_s.first(250).presence, subject: subject.to_s.squish.first(SUBJECT_LIMIT).presence, ticket: ticket)
    oldest_kept = where(organization: organization).newest_first.offset(KEEP - 1).pick(:id)
    where(organization: organization).where(id: ...oldest_kept).delete_all if oldest_kept
  rescue StandardError => e
    Rails.logger.error("Mail log of organization #{organization.id}: #{e.class}: #{e.message}")
  end
end
