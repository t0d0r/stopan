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
    user.staff? || own?
  end

  def note?
    user.staff?
  end

  def comment?
    reply? || note?
  end

  def update?
    user.staff?
  end

  def resolve?
    ticket.resolvable_by_requester? && (user.staff? || own?)
  end

  # Share links (specs/sharing.md): staff, or the requester for their own ticket.
  def share?
    user.staff? || own?
  end

  # Editing text (specs/timeline.md "Editing"): staff any request, reply or
  # note; the requester their own request and own public replies.
  def edit_description?
    user.staff? || own?
  end

  def edit_comment?(comment)
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
