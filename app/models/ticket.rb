class Ticket < ApplicationRecord
  include Attachable
  include Editable

  STATUSES = %w[new open pending postponed done].freeze
  UNSOLVED = %w[new open pending].freeze
  # The one finished status; replies reopen it (specs/tickets.md).
  DONE = "done"
  # Parked for later ("Not now"); neither unsolved nor done (board.md).
  POSTPONED = "postponed"
  # What a requester's "Open" tab holds (specs/queues.md).
  OPEN_FOR_REQUESTER = (UNSOLVED + [ POSTPONED ]).freeze
  PRIORITIES = %w[low normal high urgent].freeze
  # Manual status changes staff may make (specs/tickets.md). Nothing goes
  # back to "new".
  TRANSITIONS = {
    "new" => %w[open pending done postponed],
    "open" => %w[pending done postponed],
    "pending" => %w[open done postponed],
    "postponed" => %w[open done],
    "done" => %w[open]
  }.freeze
  FIRST_NUMBER = 1001
  # Where a ticket came from (specs/public-form.md, organization-mail.md).
  SOURCES = %w[app web_form email].freeze
  SHARE_PASSWORD_LENGTH = 6..72
  # Fields whose changes are written to the timeline, and whether the
  # requester may see them (specs/timeline.md).
  TRACKED = { "status" => false, "priority" => true, "assignee_id" => true, "stage_id" => true }.freeze

  belongs_to :requester, class_name: "User", inverse_of: :requested_tickets
  belongs_to :assignee, class_name: "User", optional: true, inverse_of: :assigned_tickets
  belongs_to :organization
  # The board stage within the status (specs/board.md "Stages").
  belongs_to :stage, optional: true
  belongs_to :deleted_by, class_name: "User", optional: true
  has_many :comments, -> { order(:created_at, :id) }, inverse_of: :ticket, dependent: :restrict_with_error
  has_many :events, -> { order(:created_at, :id) }, class_name: "TicketEvent", inverse_of: :ticket,
           dependent: :restrict_with_error

  # The share password is optional (specs/sharing.md).
  has_secure_password :share_password, validations: false, reset_token: false

  scope :shared, -> { where.not(share_token: nil) }
  # Soft-deleted tickets (specs/tickets.md "Deleting"), for administrators only.
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Who makes the change being saved; events name them. Falls back to the
  # signed-in user of the request.
  attr_accessor :actor

  normalizes :subject, with: ->(subject) { subject.squish }
  # Lines are stored with LF, as browsers send CRLF (specs/timeline.md).
  normalizes :description, with: ->(description) { description.gsub(/\r\n?/, "\n") }

  validates :subject, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 20_000 }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :source, inclusion: { in: SOURCES }
  validate :requester_belongs_to_organization, if: -> { requester_id_changed? || organization_id_changed? }
  validate :assignee_is_active_staff, if: -> { assignee_id_changed? && assignee_id.present? }
  validate :status_transition_allowed, if: -> { persisted? && status_changed? }
  validate :stage_matches_status, if: -> { stage_id.present? }

  before_create { self.number ||= Ticket.next_number }
  # A status change leaves a stage that belongs to another status.
  before_validation { self.stage = nil if stage && stage.status != status }
  before_save :stamp_status_times, if: :status_changed?
  after_create :record_created
  after_update :record_changes

  scope :unsolved, -> { where(status: UNSOLVED) }
  scope :done, -> { where(status: DONE) }

  # Administrators see every ticket, agents those of their organizations,
  # requesters only their own in the organizations they still belong to
  # (specs/roles.md).
  def self.visible_to(user)
    return none unless user
    # Deleted tickets are gone for everyone (specs/tickets.md "Deleting").
    return where(deleted_at: nil) if user.admin?

    scope = where(deleted_at: nil, organization_id: user.memberships.select(:organization_id))
    user.staff? ? scope : scope.where(requester_id: user.id)
  end

  # Write transactions on SQLite are immediate (Rails 8), so reading the
  # highest number and inserting happen under one lock.
  def self.next_number
    # Never reuse numbers of flushed tickets (specs/admin.md "Flush all tickets").
    [ maximum(:number) || FIRST_NUMBER - 1, AppSetting.current.last_ticket_number ].max + 1
  end

  # Events written in the current transaction, waiting for TicketNotifier.
  def notification_batch
    @notification_batch ||= []
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

  def done?
    status == DONE
  end

  # Statuses staff may pick now: the current one plus allowed transitions.
  def next_statuses
    TRANSITIONS.fetch(status_was || status, [])
  end

  def resolvable_by_requester?
    OPEN_FOR_REQUESTER.include?(status)
  end

  def shared?
    share_token.present?
  end

  def share_password?
    share_password_digest.present?
  end

  # Makes a new share link, so sharing again revokes the old one
  # (specs/sharing.md). The columns are written without touching updated_at:
  # sharing is not activity on the ticket. Returns false for a bad password.
  def share!(actor:, password: nil)
    password = password.presence
    if password && !SHARE_PASSWORD_LENGTH.cover?(password.length)
      errors.add(:share_password, password.length < SHARE_PASSWORD_LENGTH.min ? :too_short : :too_long,
                 count: password.length < SHARE_PASSWORD_LENGTH.min ? SHARE_PASSWORD_LENGTH.min : SHARE_PASSWORD_LENGTH.max)
      return false
    end

    self.share_password = password
    old_token = share_token
    transaction do
      update_columns(share_token: SecureRandom.base58(32), share_password_digest: share_password_digest,
                     shared_at: Time.current)
      events.create!(action: "shared", actor: actor, internal: true, to_value: ("password" if password))
    end
    refresh_shared_page(old_token)
    true
  end

  def deleted?
    deleted_at.present?
  end

  # Soft delete (specs/tickets.md "Deleting"): the ticket disappears for
  # everyone, its share link stops, an internal event records who did it.
  def soft_delete!(actor:)
    return if deleted?

    transaction do
      unshare!(actor: actor)
      update_columns(deleted_at: Time.current, deleted_by_id: actor.id)
      events.create!(action: "deleted", actor: actor, internal: true)
    end
  end

  def restore!(actor:)
    return unless deleted?

    transaction do
      update_columns(deleted_at: nil, deleted_by_id: nil)
      events.create!(action: "restored", actor: actor, internal: true)
    end
  end

  # A ticket from email is read through its share link, with the
  # requester's address as password (specs/sharing.md "Link in the
  # requester's emails"). Keeps an existing link.
  def share_with_requester!
    return if shared? || source != "email"

    share!(actor: nil, password: requester.email)
  end

  # The link to give in an email to this recipient, or nil for the ticket
  # page: the requester of a ticket from email, when the link is open or
  # its password is their address.
  def share_link_for(recipient)
    return unless shared? && source == "email" && recipient == requester
    return :open unless share_password?

    :email_password if authenticate_share_password(recipient.email)
  end

  def unshare!(actor:)
    return unless shared?

    old_token = share_token
    transaction do
      update_columns(share_token: nil, share_password_digest: nil, shared_at: nil)
      events.create!(action: "unshared", actor: actor, internal: true)
    end
    refresh_shared_page(old_token)
  end

  # Stream of the share page: the ticket plus a hash of the token, so the
  # token stays out of Action Cable's logs and the signed stream name.
  def share_stream(token = share_token)
    [ self, :share, share_digest(token) ]
  end

  # Names a link without the token itself (streams, viewer counts).
  def share_digest(token = share_token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Stream of the ticket page for this user: staff hear every change,
  # requesters only public ones (specs/timeline.md "Live updates").
  def page_stream(user)
    [ self, :page, user.staff? ? :staff : :public ]
  end

  # Stream of the ticket lists for this user (specs/queues.md "Live
  # updates"): one queue for all staff, one list per requester.
  def self.list_stream(user)
    user.staff? ? [ :queue, :staff ] : [ user, :tickets ]
  end

  # Who may be assigned tickets of an organization: administrators and its
  # agents (specs/roles.md).
  def self.assignable_staff(organization_id)
    User.active.where(role: "admin")
        .or(User.active.where(role: "agent", id: Membership.where(organization_id: organization_id).select(:user_id)))
        .ordered
  end

  # Staff an agent may pick in filters: administrators and the agents of
  # the user's organizations (everyone's for administrators).
  def self.assignable_staff_for(user)
    return User.staff.active.ordered if user.admin?

    assignable_staff(user.memberships.select(:organization_id))
  end

  def assignable_staff
    self.class.assignable_staff(organization_id)
  end

  # Every list stream a user's ticket list listens to (specs/queues.md).
  def self.list_streams(user)
    [ list_stream(user) ]
  end

  # Tells open ticket pages and ticket lists to reload themselves; internal
  # changes reach only staff. The signal carries no content.
  def refresh_pages(internal:)
    Turbo::StreamsChannel.broadcast_refresh_later_to(self, :page, :staff)
    Turbo::StreamsChannel.broadcast_refresh_later_to(:queue, :staff)
    RefreshesAdminPages.broadcast
    return if internal

    Turbo::StreamsChannel.broadcast_refresh_later_to(self, :page, :public)
    Turbo::StreamsChannel.broadcast_refresh_later_to(requester, :tickets)
  end

  # Tells an open shared page to reload itself (specs/sharing.md); the
  # signal carries no content.
  def refresh_shared_page(token = share_token)
    Turbo::StreamsChannel.broadcast_refresh_later_to(*share_stream(token)) if token.present?
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
  def add_comment(author:, body:, internal: false, files: [], status: nil, markdown: false, source: "app")
    comment = Comment.new(ticket: self, author: author, body: body, internal: internal, files: files, markdown: markdown,
                          source: source)
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

  def revision_text
    { subject: subject_in_database, body: description_in_database }
  end

  def refresh_after_edit
    refresh_pages(internal: false)
    refresh_shared_page
  end

  def status_after(comment)
    return if comment.internal?

    if comment.author.staff?
      "open" if status == "new"
    elsif [ "pending", DONE, POSTPONED ].include?(status)
      "open"
    end
  end

  def stage_matches_status
    errors.add(:stage, :other_status) if stage && stage.status != status
  end

  def requester_belongs_to_organization
    return unless requester && organization

    errors.add(:requester, :not_a_member) unless requester.member_of?(organization)
  end

  def assignee_is_active_staff
    return errors.add(:assignee, :not_staff) unless assignee&.staff? && !assignee.deactivated?

    errors.add(:assignee, :not_in_organization) unless assignee.admin? || assignee.member_of?(organization)
  end

  def status_transition_allowed
    return if TRANSITIONS.fetch(status_was, []).include?(status)

    errors.add(:status, :transition, from: I18n.t("ui.statuses.#{status_was}"),
                                     to: I18n.t("ui.statuses.#{status}", default: status.to_s))
  end

  def stamp_status_times
    self.done_at = (Time.current if done?)
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
      # Stage events keep names, so they read the same after a stage is deleted.
      from, to = [ from, to ].map { |id| id && Stage.find_by(id: id)&.name } if field == "stage_id"
      action = { "assignee_id" => "assignee_changed", "stage_id" => "stage_changed" }.fetch(field, "#{field}_changed")
      events.create!(action: action, actor: event_actor, from_value: from, to_value: to, internal: internal)
    end
  end
end
