# Text that can be edited, keeping each earlier version
# (specs/timeline.md "Editing"). Includers name the old text for the
# revision (revision_text) and what to refresh afterwards
# (refresh_after_edit).
module Editable
  extend ActiveSupport::Concern

  included do
    belongs_to :edited_by, class_name: "User", optional: true
    has_many :revisions, -> { newest_first }, as: :record, inverse_of: :record, dependent: :restrict_with_error
  end

  def edited?
    edited_at.present?
  end

  # Saves the new text and keeps the old one as a revision. Unchanged text
  # does nothing. Returns false when the new text is invalid. The record's
  # updated_at stays: an edit is not activity.
  def edit(editor:, **text)
    assign_attributes(text)
    return true if (text.keys.map(&:to_s) & changed).empty?
    return false unless valid?

    transaction do
      revisions.create!(editor: editor, **revision_text)
      @editing = true
      update_columns(text.keys.index_with { |name| self[name] }.merge(edited_at: Time.current, edited_by_id: editor.id))
    ensure
      @editing = false
    end
    refresh_after_edit
    true
  end

  # Markdown on or off (specs/markdown.md): how the text is shown, not an
  # edit, so no revision and no edited marker.
  def switch_markdown(on)
    return if markdown? == on

    @editing = true
    update_columns(markdown: on)
    refresh_after_edit
  ensure
    @editing = false
  end
end
