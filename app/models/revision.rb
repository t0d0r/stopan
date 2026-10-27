# The text of a request or comment before one edit, and who made that edit
# (specs/timeline.md "Editing"). Only ever inserted.
class Revision < ApplicationRecord
  belongs_to :record, polymorphic: true
  belongs_to :editor, class_name: "User", inverse_of: :revisions

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end
end
