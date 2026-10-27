# One change applied to many tickets from the queue, search results or
# the API (specs/queues.md "Bulk actions"). Each ticket goes through the
# same scope, policy and apply_changes as a single change; tickets where
# the change is not allowed are skipped and reported.
class TicketBulkUpdate
  MAX = 500
  LIST_FILTERS = %i[view status priority assignee organization requester q].freeze

  Skipped = Struct.new(:ticket, :reason, keyword_init: true)

  attr_reader :user, :updated, :skipped, :unchanged

  # numbers: ticket numbers; list: the list's filter parameters instead
  # (every matching ticket, at most MAX); changes: status, priority and
  # assignee ("me", "none" or a user id), blanks meaning "no change";
  # delete: soft delete them instead (specs/tickets.md "Deleting").
  def initialize(user:, changes:, numbers: nil, list: nil, delete: false)
    @delete = delete
    @user = user
    @numbers = Array(numbers).map(&:to_s).first(MAX)
    @list = list
    @changes = changes.to_h.symbolize_keys.slice(:status, :priority, :assignee).compact_blank
    @updated = []
    @skipped = []
    @unchanged = []
  end

  def changes?
    @delete || @changes.any?
  end

  def delete?
    @delete
  end

  def tickets
    @tickets ||= begin
      scope = @list ? TicketFilter.new(user, ActionController::Parameters.new(@list.to_h).permit(*LIST_FILTERS)).scope
                    : Ticket.visible_to(user).where(number: @numbers)
      scope.includes(:organization).order(:number).limit(MAX).to_a
    end
  end

  def run
    tickets.each { |ticket| apply(ticket) } if changes?
    self
  end

  private

  def apply(ticket)
    return skip(ticket, I18n.t("ui.bulk.not_allowed")) unless TicketPolicy.new(user, ticket).update?
    if @delete
      ticket.soft_delete!(actor: user)
      return @updated << ticket
    end

    changes = {}
    changes[:status] = @changes[:status] if @changes[:status] && @changes[:status] != ticket.status
    changes[:priority] = @changes[:priority] if @changes[:priority] && @changes[:priority] != ticket.priority
    if @changes.key?(:assignee)
      assignee_id = assignee_id_for(ticket)
      return skip(ticket, I18n.t("ui.bulk.assignee_not_allowed")) if assignee_id == :invalid

      changes[:assignee_id] = assignee_id if assignee_id != ticket.assignee_id
    end
    return @unchanged << ticket if changes.empty?

    if ticket.apply_changes(changes, actor: user)
      @updated << ticket
    else
      skip(ticket, ticket.errors.full_messages.to_sentence)
    end
  end

  # nil for "none", the user's id for "me", an assignable staff id, or
  # :invalid when that person may not work this ticket.
  def assignee_id_for(ticket)
    case @changes[:assignee].to_s
    when "none" then nil
    when "me" then ticket.assignable_staff.exists?(user.id) ? user.id : :invalid
    else ticket.assignable_staff.find_by(id: @changes[:assignee])&.id || :invalid
    end
  end

  def skip(ticket, reason)
    @skipped << Skipped.new(ticket: ticket, reason: reason)
  end
end
