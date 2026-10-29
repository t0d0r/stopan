# What a user reaches in the admin area (specs/org-admins.md): super
# administrators everything, organization administrators their
# organizations, the members and accounts in them, and nothing else.
# Controllers find records only through these scopes, so anything outside
# is a 404.
class AdminScope
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def super_admin?
    user.admin?
  end

  def organizations
    user.administered_organizations
  end

  # Roles the user may give in the user form.
  def roles
    super_admin? ? User::ROLES : %w[requester agent]
  end

  # The users list: members of the administered organizations.
  def users
    return User.all if super_admin?

    User.where(id: Membership.where(organization_id: organizations.select(:id)).select(:user_id))
  end

  # Users the organization administrator may edit or delete: no one above
  # agent, no other organization administrator, not themselves, and no
  # membership outside their organizations.
  def manageable_users
    return User.all if super_admin?

    users.where.not(role: "admin").where.not(id: user.id)
         .where.not(id: Membership.administering.select(:user_id))
         .where.not(id: Membership.where.not(organization_id: organizations.select(:id)).select(:user_id))
  end

  # Users that may be added to an administered organization: members of
  # one of them, or of none, never super administrators.
  def addable_users
    return User.active if super_admin?

    candidates = User.active.where.not(role: "admin")
    candidates.where(id: users.select(:id)).or(candidates.where.not(id: Membership.select(:user_id)))
  end

  # A membership may be removed except the organization administrator's
  # own, those of other organization administrators and of super
  # administrators.
  def removable?(membership)
    super_admin? || (membership.user_id != user.id && !membership.admin? && !membership.user.admin?)
  end

  def deleted_tickets
    super_admin? ? Ticket.deleted : Ticket.deleted.where(organization_id: organizations.select(:id))
  end
end
