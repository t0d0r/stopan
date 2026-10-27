# A message from an administrator to one user, a role, an organization's
# members or everyone, delivered as notifications (specs/notifications.md
# "Messages from administrators").
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
    audience.active.where.not(id: sender&.id).distinct
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
    case recipients.to_s
    when "all" then User.all
    when /\Arole:(\w+)\z/ then User::ROLES.include?($1) ? User.where(role: $1) : User.none
    when /\Aorganization:(\d+)\z/ then User.joins(:memberships).where(memberships: { organization_id: $1 })
    when /\Auser:(\d+)\z/ then User.where(id: $1)
    else User.none
    end
  end

  def recipients_known
    errors.add(:recipients, :blank) if recipient_users.none?
  end
end
