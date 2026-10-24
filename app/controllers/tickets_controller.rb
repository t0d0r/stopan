class TicketsController < ApplicationController
  include TicketTimeline

  before_action :set_ticket, only: %i[show update resolve]

  def index
    @filter = TicketFilter.new(current_user, params)
  end

  def show
    @comment = Comment.new
    prepare_timeline
  end

  def new
    @ticket = Ticket.new(organization: current_user.organizations.one? ? current_user.organizations.first : nil)
  end

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.actor = current_user
    unless current_user.staff?
      @ticket.requester = current_user
      @ticket.organization ||= current_user.organizations.first if current_user.organizations.one?
    end

    if TicketPolicy.new(current_user, @ticket).create? && @ticket.save
      redirect_to @ticket, notice: t("flash.ticket_created", reference: @ticket.reference)
    else
      @ticket.errors.add(:organization, :no_membership) unless current_user.staff? || current_user.memberships.exists?
      render :new, status: :unprocessable_content
    end
  end

  # Staff change status, priority and assignee (specs/tickets.md).
  def update
    authorize! policy.update?
    if @ticket.apply_changes(update_params, actor: current_user)
      redirect_to @ticket, notice: t("flash.ticket_updated", reference: @ticket.reference)
    else
      @comment = Comment.new
      prepare_timeline
      render :show, status: :unprocessable_content
    end
  end

  # The requester's "Mark as resolved".
  def resolve
    authorize! policy.resolve?
    @ticket.apply_changes!({ status: "resolved" }, actor: current_user)
    redirect_to @ticket, notice: t("flash.ticket_resolved", reference: @ticket.reference)
  end

  private

  def set_ticket
    @ticket = find_visible_ticket(params[:id])
  end

  # Requesters choose only the text, the organization and files; the server
  # sets everything else (specs/roles.md, strong parameters per role).
  def ticket_params
    fields = %i[subject description organization_id]
    fields += %i[requester_id priority assignee_id] if current_user.staff?
    params.expect(ticket: [ *fields, files: [] ])
  end

  def update_params
    params.expect(ticket: %i[status priority assignee_id])
  end
end
