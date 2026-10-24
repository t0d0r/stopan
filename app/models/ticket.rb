class Ticket < ApplicationRecord
  include Attachable

  STATUSES = %w[new open pending resolved closed].freeze
  UNSOLVED = %w[new open pending].freeze
  SOLVED = %w[resolved closed].freeze
  PRIORITIES = %w[low normal high urgent].freeze
  # Manual status changes staff may make (specs/tickets.md). Nothing goes
  # back to "new".
  TRANSITIONS = {
    "new" => %w[open pending resolved closed],
    "open" => %w[pending resolved closed],
    "pending" => %w[open resolved closed],
    "resolved" => %w[open closed],
    "closed" => %w[open]
  }.freeze
  FIRST_NUMBER = 1001
  # Fields whose changes are written to the timeline, and whether the
  # requester may see them (specs/timeline.md).
  TRACKED = { "status" => false, "priority" => true, "assignee_id" => true }.freeze

  belongs_to :requester, class_name: "User", inverse_of: :requested_tickets
  belongs_to :assignee, class_name: "User", optional: true, inverse_of: :assigned_tickets
  belongs_to :organization
  has_many :comments, -> { order(:created_at, :id) }, inverse_of: :ticket, dependent: :restrict_with_error
  has_many :events, -> { order(:created_at, :id) }, class_name: "TicketEvent", inverse_of: :ticket,
           dependent: :restrict_with_error

  # Who makes the change being saved; events name them. Falls back to the
  # signed-in user of the request.
  attr_accessor :actor

  normalizes :subject, with: ->(subject) { subject.squish }

  validates :subject, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 20_000 }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validate :requester_belongs_to_organization, if: -> { requester_id_changed? || organization_id_changed? }
  validate :assignee_is_active_staff, if: -> { assignee_id_changed? && assignee_id.present? }
  validate :status_transition_allowed, if: -> { persisted? && status_changed? }

  before_create { self.number ||= Ticket.next_number }
  before_save :stamp_status_times, if: :status_changed?
  after_create :record_created
  after_update :record_changes

  scope :unsolved, -> { where(status: UNSOLVED) }
  scope :solved, -> { where(status: SOLVED) }

  # Staff see every ticket; a requester sees their own tickets in the
  # organizations they still belong to (specs/roles.md).
  def self.visible_to(user)
    return none unless user
    return all if user.staff?

    where(requester_id: user.id, organization_id: user.memberships.select(:organization_id))
  end

  # Write transactions on SQLite are immediate (Rails 8), so reading the
  # highest number and inserting happen under one lock.
  def self.next_number
    (maximum(:number) || FIRST_NUMBER - 1) + 1
  end

  def to_param
    number&.to_s
  end

  def reference
    "##{number}"
  end

  def unsolved?
    UNSOLVED.include?(status)
  end

  def closed?
    status == "closed"
  end

  # Statuses staff may pick now: the current one plus allowed transitions.
  def next_statuses
    TRANSITIONS.fetch(status_was || status, [])
  end

  def resolvable_by_requester?
    UNSOLVED.include?(status)
  end

  # Saves property changes made by staff (or the system) in one transaction;
  # each changed field writes its own event.
  def apply_changes!(changes, actor:)
    self.actor = actor
    assign_attributes(changes)
    save!
  end

  def apply_changes(changes, actor:)
    apply_changes!(changes, actor: actor)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Adds a reply or internal note, and changes the status when asked or when
  # the rules in specs/tickets.md say so, all in one transaction. Returns
  # the comment; it is not persisted when something was invalid.
  def add_comment(author:, body:, internal: false, files: [], status: nil)
    comment = Comment.new(ticket: self, author: author, body: body, internal: internal, files: files)
    transaction do
      comment.save!
      new_status = status.presence || status_after(comment)
      apply_changes!({ status: new_status }, actor: author) if new_status && new_status != self.status
    end
    comment
  rescue ActiveRecord::RecordInvalid
    errors.full_messages.each { |message| comment.errors.add(:base, message) }
    restore_attributes(%i[status])
    comment
  end

  private

  def status_after(comment)
    return if comment.internal?

    if comment.author.staff?
      "open" if status == "new"
    elsif %w[pending resolved].include?(status)
      "open"
    end
  end

  def requester_belongs_to_organization
    return unless requester && organization

    errors.add(:requester, :not_a_member) unless requester.member_of?(organization)
  end

  def assignee_is_active_staff
    errors.add(:assignee, :not_staff) unless assignee&.staff? && !assignee.deactivated?
  end

  def status_transition_allowed
    return if TRANSITIONS.fetch(status_was, []).include?(status)

    errors.add(:status, :transition, from: I18n.t("ui.statuses.#{status_was}"),
                                     to: I18n.t("ui.statuses.#{status}", default: status.to_s))
  end

  def stamp_status_times
    case status
    when "resolved" then self.resolved_at = Time.current
    when "closed" then self.closed_at = Time.current
    when "open", "pending" then self.resolved_at = self.closed_at = nil
    end
  end

  def event_actor
    actor || Current.user
  end

  def record_created
    events.create!(action: "created", actor: event_actor, internal: false)
  end

  def record_changes
    TRACKED.each do |field, internal|
      next unless saved_change_to_attribute?(field)

      from, to = saved_change_to_attribute(field)
      action = field == "assignee_id" ? "assignee_changed" : "#{field}_changed"
      events.create!(action: action, actor: event_actor, from_value: from, to_value: to, internal: internal)
    end
  end
end
