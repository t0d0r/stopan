# A message from an administrator to one user, a role, an organization's
# members or everyone, delivered as notifications (specs/notifications.md
# "Messages from administrators"). Organization administrators write only
# to the members of their organizations (specs/org-admins.md).
class AdminMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  ROLE_AUDIENCES = User::ROLES.map { |role| "role:#{role}" }.freeze

  attribute :recipients, :string
  attribute :text, :string
  attr_accessor :sender

  validates :text, presence: true, length: { maximum: Notification::MESSAGE_LENGTH }
  validate :recipients_known

  # Active users the message goes to, never the sender.
  def recipient_users
    audience.active.where.not(id: sender&.id)
            .where("users.role = 'admin' OR EXISTS (SELECT 1 FROM memberships m WHERE m.user_id = users.id)").distinct
  end

  # Creates one notification per recipient and returns how many.
  def deliver
    users = recipient_users.to_a
    Notification.transaction do
      users.each { |user| Notification.create!(user: user, actor: sender, kind: "message", message: text.strip) }
    end
    users.size
  end

  private

  def audience
    return User.none unless sender_may_address?

    case recipients.to_s
    when "all" then User.all
    when /\Arole:(\w+)\z/ then User::ROLES.include?($1) ? User.where(role: $1) : User.none
    when /\Aorganization:(\d+)\z/ then User.joins(:memberships).where(memberships: { organization_id: $1 })
    when /\Auser:(\d+)\z/ then User.where(id: $1)
    else User.none
    end
  end

  def sender_may_address?
    return true if sender.nil? || sender.admin?

    case recipients.to_s
    when /\Aorganization:(\d+)\z/ then sender.administered_organizations.exists?(id: $1)
    when /\Auser:(\d+)\z/ then AdminScope.new(sender).users.exists?(id: $1)
    else false
    end
  end

  def recipients_known
    errors.add(:recipients, :blank) if recipient_users.none?
  end
end
