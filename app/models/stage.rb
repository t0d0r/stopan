# A board stage: a named sub-column of a status, for staff only
# (specs/board.md "Stages").
class Stage < ApplicationRecord
  COLORS = %w[yellow blue green pink purple gray].freeze

  has_many :tickets, dependent: :nullify

  normalizes :name, with: ->(name) { name.squish }

  validates :status, inclusion: { in: Ticket::STATUSES }
  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { scope: :status, case_sensitive: false }
  validates :color, inclusion: { in: COLORS }

  before_create { self.position = (Stage.where(status: status).maximum(:position) || 0) + 1 }

  scope :ordered, -> { order(:position, :id) }

  # Swaps places with the neighbour above (-1) or below (1) within its
  # status.
  def move(step)
    siblings = Stage.where(status: status).ordered.to_a
    index = siblings.index(self)
    other = siblings[index + step] if index && (index + step).between?(0, siblings.size - 1)
    return unless other

    Stage.transaction do
      mine = position
      update!(position: other.position)
      other.update!(position: mine)
    end
  end
end
