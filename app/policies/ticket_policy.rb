# What a user may do with a ticket they can already see (specs/roles.md).
# Visibility itself is Ticket.visible_to; controllers load tickets through
# it first, so an invisible ticket is a 404 before any of these is asked.
class TicketPolicy
  attr_reader :user, :ticket

  def initialize(user, ticket)
    @user = user
    @ticket = ticket
  end

  def show?
    Ticket.visible_to(user).exists?(ticket.id)
  end

  # Requesters open tickets only for an organization they belong to.
  def create?
    user.staff? || user.memberships.exists?
  end

  def reply?
    return false if ticket.deleted?

    user.staff? || own?
  end

  def note?
    user.staff? && !ticket.deleted?
  end

  def comment?
    reply? || note?
  end

  def update?
    user.staff? && !ticket.deleted?
  end

  # Soft delete (specs/tickets.md "Deleting"): staff who may update it.
  def delete?
    update?
  end

  # Bringing a deleted ticket back: super administrators, and organization
  # administrators of its organization (specs/org-admins.md).
  def restore?
    ticket.deleted? && user.administers?(ticket.organization)
  end

  def resolve?
    !ticket.deleted? && ticket.resolvable_by_requester? && (user.staff? || own?)
  end

  # Share links (specs/sharing.md): staff, or the requester for their own ticket.
  def share?
    return false if ticket.deleted?

    user.staff? || own?
  end

  # Editing text (specs/timeline.md "Editing"): staff any request, reply or
  # note; the requester their own request and own public replies.
  def edit_description?
    return false if ticket.deleted?

    user.staff? || own?
  end

  def edit_comment?(comment)
    return false if ticket.deleted?
    return true if user.staff?

    comment.author_id == user.id && !comment.internal? && own?
  end

  def see_revisions?
    user.staff?
  end

  def see_internal?
    user.staff?
  end

  private

  def own?
    ticket.requester_id == user.id && user.member_of?(ticket.organization)
  end
end
