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
  # Days a share link may be given (specs/sharing.md "Expiry").
  SHARE_EXPIRY_DAYS = [ 1, 7, 30 ].freeze
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
  # Staff followers and people in Cc (specs/followers.md).
  has_many :ticket_followers, dependent: :delete_all
  has_many :followers, through: :ticket_followers, source: :user

  # The share password is optional (specs/sharing.md).
  has_secure_password :share_password, validations: false, reset_token: false

  # An expired link is not shared, whether or not the timer cleared it
  # yet (specs/sharing.md "Expiry").
  scope :shared, -> {
    where.not(share_token: nil).where("tickets.share_expires_at IS NULL OR tickets.share_expires_at > ?", Time.current)
  }
  scope :share_expired, -> { where.not(share_token: nil).where(share_expires_at: ..Time.current) }
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

  # Staff (super administrators too, since 2026-11-02) see the tickets of
  # their organizations, requesters their own and those they are Cc on, in
  # the organizations they still belong to (specs/roles.md,
  # specs/followers.md).
  def self.visible_to(user)
    return none unless user

    # Deleted tickets are gone for everyone (specs/tickets.md "Deleting").
    scope = where(deleted_at: nil, organization_id: user.memberships.select(:organization_id))
    return scope if user.staff?

    scope.where(requester_id: user.id).or(scope.where(id: TicketFollower.where(user_id: user.id).select(:ticket_id)))
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
    share_token.present? && !share_expired?
  end

  def share_expired?
    share_expires_at.present? && share_expires_at <= Time.current
  end

  def share_password?
    share_password_digest.present?
  end

  # Makes a new share link, so sharing again revokes the old one
  # (specs/sharing.md). The columns are written without touching updated_at:
  # sharing is not activity on the ticket. Returns false for a bad password.
  def share!(actor:, password: nil, expires_in_days: nil)
    password = password.presence
    days = expires_in_days.presence&.to_s
    if days && !SHARE_EXPIRY_DAYS.map(&:to_s).include?(days)
      errors.add(:share_expires_at, :inclusion)
      return false
    end
    days = days&.to_i
    if password && !SHARE_PASSWORD_LENGTH.cover?(password.length)
      errors.add(:share_password, password.length < SHARE_PASSWORD_LENGTH.min ? :too_short : :too_long,
                 count: password.length < SHARE_PASSWORD_LENGTH.min ? SHARE_PASSWORD_LENGTH.min : SHARE_PASSWORD_LENGTH.max)
      return false
    end

    self.share_password = password
    old_token = share_token
    transaction do
      update_columns(share_token: SecureRandom.base58(32), share_password_digest: share_password_digest,
                     shared_at: Time.current, share_expires_at: days&.days&.from_now,
                     share_views: 0, share_last_viewed_at: nil)
      events.create!(action: "shared", actor: actor, internal: true, to_value: ("password" if password),
                     detail: days&.to_s)
    end
    refresh_shared_page(old_token)
    true
  end

  def deleted?
    deleted_at.present?
  end

  # Emails to the requester on or off (specs/notifications.md "Emails to
  # the requester"): written without touching updated_at, with an internal
  # event naming who did it.
  def switch_requester_mail!(on, actor:)
    return if email_requester == on

    transaction do
      update_columns(email_requester: on)
      events.create!(action: "mail_switched", actor: actor, internal: true,
                     from_value: on ? "off" : "on", to_value: on ? "on" : "off")
    end
  end

  # One email to the customer side sent, not sent or failed, for staff to
  # see in the history (same section, specs/followers.md).
  def record_customer_mail(action, kind, address, detail = nil)
    events.create!(action: action, internal: true, from_value: kind.to_s, to_value: address.to_s.first(200),
                   detail: detail&.to_s&.squish&.first(200))
  end

  # The requester and the people in Cc (specs/followers.md).
  def customer?(user)
    user.id == requester_id || cc?(user)
  end

  def cc?(user)
    !user.staff? && ticket_followers.exists?(user_id: user.id)
  end

  def cc_users
    followers.merge(User.requesters).order(:name, :email)
  end

  def staff_followers
    followers.merge(User.staff).ordered
  end

  # Addresses the customer-side emails go to, for the composer's warning.
  def customer_emails
    [ requester.email, *cc_users.active.where(id: organization.memberships.select(:user_id)).pluck(:email) ].uniq
  end

  # A staff member follows: themselves or added by a colleague.
  def follow!(user, actor:)
    add_follower(user, actor: actor, kind: "staff")
  end

  # A staff member of the organization by id, themselves or a colleague, as
  # the panel and the API add them. Returns the follower, or nil with the
  # reason in errors when they are on the ticket already.
  def add_staff_follower!(user_id, actor:)
    user = Ticket.assignable_staff(organization_id).find(user_id)
    return follower_refused(:taken) if ticket_followers.exists?(user_id: user.id)

    follow!(user, actor: actor)
  end

  # Someone from the customer side in Cc, found or created by address like
  # an email to the mailbox would (specs/followers.md "Adding to Cc by
  # email"). Returns the follower, or nil with the reason in errors.
  def add_cc!(email, actor:)
    address = email.to_s.strip.downcase
    return follower_refused(:invalid) unless address.match?(URI::MailTo::EMAIL_REGEXP)

    user = User.find_by("lower(email) = ?", address)
    return follower_refused(:staff) if user&.staff?
    return follower_refused(:deactivated) if user&.deactivated?
    return follower_refused(:requester) if user && user.id == requester_id
    return follower_refused(:taken) if user && ticket_followers.exists?(user_id: user.id)

    transaction do
      user ||= User.create!(name: address.split("@").first.first(100), email: address, password: SecureRandom.base58(32),
                            role: "requester", password_chosen: false)
      Membership.find_or_create_by!(user: user, organization: organization)
      add_follower(user, actor: actor, kind: "cc")
    end
  end

  # Colleagues the requester may put in Cc: active requesters who are
  # members of the organization and not on the ticket yet
  # (specs/followers.md "The requester adds colleagues").
  def cc_candidates
    User.requesters.active.where(id: organization.memberships.select(:user_id))
        .where.not(id: requester_id).where.not(id: ticket_followers.select(:user_id)).ordered
  end

  # One of them by id; anyone else is not found.
  def add_cc_member!(user_id, actor:)
    add_follower(cc_candidates.find(user_id), actor: actor, kind: "cc")
  end

  # Addresses from the mail's To and Cc that could be put in Cc, never
  # added on their own (specs/followers.md "The panel").
  def cc_suggestions
    return [] if mail_headers.blank?

    addresses = Array(mail_headers["to"]) + Array(mail_headers["cc"])
    addresses = addresses.filter_map { |value| (value.to_s[/<([^>]+)>/, 1] || value.to_s).strip.downcase.presence }.uniq
    own = [ organization.mail_from_address, organization.mailbox_address, requester.email ].compact.map(&:downcase)
    known = User.where("lower(email) IN (?)", addresses)
    taken = known.where(id: ticket_followers.select(:user_id)).or(known.staff).pluck(:email).map(&:downcase)
    (addresses - own - taken).select { |address| address.match?(URI::MailTo::EMAIL_REGEXP) }.first(10)
  end

  # The person takes themself off the ticket: on the panel, by the link in
  # their email or through the API (specs/followers.md "Leaving").
  def leave!(follower)
    remove_follower!(follower, actor: follower.user)
  end

  def remove_follower!(follower, actor:)
    transaction do
      follower.destroy!
      events.create!(action: "follower_removed", actor: actor, internal: true,
                     from_value: follower.cc? ? "cc" : "staff", to_value: follower.user_id.to_s)
    end
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
  # requester's emails"); people in Cc read every ticket that way, most
  # have no password of their own (specs/followers.md). Keeps an existing
  # link.
  def share_for_customer!(recipient)
    return if shared? || !shared_link_recipient?(recipient)

    share!(actor: nil, password: requester.email)
  end

  # The link to give in an email to this recipient, or nil for the ticket
  # page: the requester of a ticket from email or someone in Cc, when the
  # link is open or its password is the requester's address (the shared
  # page also takes a Cc's own address then).
  def share_link_for(recipient)
    return unless shared? && shared_link_recipient?(recipient)
    return :open unless share_password?

    :email_password if authenticate_share_password(requester.email)
  end

  def shared_link_recipient?(recipient)
    (recipient.id == requester_id && source == "email") || cc?(recipient)
  end

  # The share password is an email address of the customer side: the
  # requester's (stored), or a current Cc's on the automatic link
  # (specs/followers.md "Notifications and emails").
  def customer_share_password?(address)
    address = address.to_s.strip.downcase
    address.include?("@") && customer_emails.map(&:downcase).include?(address) &&
      authenticate_share_password(requester.email).present?
  end

  def unshare!(actor:)
    return unless shared?

    clear_share!("unshared", actor)
  end

  # The link's time ran out (ShareExpiry): cleared like a stopped link,
  # without an actor. True when it was cleared.
  def expire_share!
    return false unless share_token.present? && share_expired?

    clear_share!("share_expired", nil)
    true
  end

  # One more view of the shared page (specs/sharing.md "Total views"):
  # counted in the database, so two at once are not lost, and without
  # touching updated_at.
  def count_share_view!
    Ticket.where(id: id).update_all([ "share_views = share_views + 1, share_last_viewed_at = ?", Time.current ])
  end

  def clear_share!(action, actor)
    old_token = share_token
    transaction do
      update_columns(share_token: nil, share_password_digest: nil, shared_at: nil, share_expires_at: nil,
                     share_views: 0, share_last_viewed_at: nil)
      events.create!(action: action, actor: actor, internal: true)
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

  # Who may be assigned tickets of an organization: its active staff,
  # agents and super administrators (specs/roles.md).
  def self.assignable_staff(organization_id)
    User.active.staff.where(id: Membership.where(organization_id: organization_id).select(:user_id)).ordered
  end

  # Staff a user may pick in filters: the staff of the user's organizations.
  def self.assignable_staff_for(user)
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
    # The people in Cc have the ticket in their lists too (specs/followers.md).
    cc_users.each { |user| Turbo::StreamsChannel.broadcast_refresh_later_to(user, :tickets) }
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
  def add_comment(author:, body:, internal: false, files: [], status: nil, markdown: false, source: "app", mail_headers: nil,
                  mail_html: nil)
    comment = Comment.new(ticket: self, author: author, body: body, internal: internal, files: files, markdown: markdown,
                          source: source, mail_headers: mail_headers, mail_html: mail_html)
    transaction do
      comment.save!
      new_status = status.presence || status_after(comment)
      apply_changes!({ status: new_status }, actor: author) if new_status && new_status != self.status
      follow_as_author(author)
    end
    comment
  rescue ActiveRecord::RecordInvalid
    errors.full_messages.each { |message| comment.errors.add(:base, message) }
    restore_attributes(%i[status])
    comment
  end

  private

  def add_follower(user, actor:, kind:)
    transaction do
      follower = ticket_followers.create!(user: user, added_by: actor)
      events.create!(action: "follower_added", actor: actor, internal: true, from_value: kind, to_value: user.id.to_s)
      follower
    end
  end

  def follower_refused(reason)
    errors.add(:base, I18n.t("ui.followers.refused.#{reason}"))
    nil
  end

  # Staff who write on a ticket follow it from then on, silently
  # (specs/followers.md "Following automatically").
  def follow_as_author(author)
    return unless author.staff? && !ticket_followers.exists?(user_id: author.id)

    ticket_followers.create(user: author, added_by: author)
  end

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

    errors.add(:assignee, :not_in_organization) unless assignee.member_of?(organization)
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
