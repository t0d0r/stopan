# Read-only page of a ticket for anyone with its share link
# (specs/sharing.md). It shows only what the requester sees; a link with a
# password asks for it once per browser session.
class SharedTicketsController < ApplicationController
  include FileSending

  # Per process; enough to slow down guessing a share password.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  UNLOCKED_LIMIT = 20

  skip_before_action :authenticate_user!
  before_action :set_private_headers
  before_action :set_ticket
  before_action :require_unlocked, except: :unlock

  # Per token, not per IP: the client IP behind the production proxies is
  # not confirmed yet (specs/roadmap.md).
  rate_limit to: 10, within: 5.minutes, only: :unlock, store: RATE_LIMIT_STORE,
             by: -> { params[:token].to_s },
             with: -> {
               flash.now[:alert] = t("flash.share_too_many_attempts")
               render :password, status: :too_many_requests
             }

  def show
    @events = TicketEvent.where(ticket: @ticket, internal: false)
                         .includes(:actor, comment: [ :author, { files_attachments: :blob } ])
                         .order(:created_at, :id).to_a
  end

  def unlock
    if !@ticket.share_password? || @ticket.authenticate_share_password(params[:password].to_s)
      remember_unlocked
      redirect_to shared_ticket_path(@ticket.share_token)
    else
      flash.now[:alert] = t("flash.share_wrong_password")
      render :password, status: :unprocessable_content
    end
  end

  def file
    send_blob(find_public_attachment.blob)
  end

  def file_preview
    send_blob_preview(find_public_attachment.blob)
  end

  private

  # Files of the ticket and of its public replies only.
  def find_public_attachment
    public_comments = @ticket.comments.where(internal: false).select(:id)
    ActiveStorage::Attachment.where(name: "files", record_type: "Ticket", record_id: @ticket.id)
      .or(ActiveStorage::Attachment.where(name: "files", record_type: "Comment", record_id: public_comments))
      .find(params[:id])
  end

  # The token is the secret: keep it out of Referer headers sent to other
  # sites, caches and search engines. "no-referrer" would make browsers send
  # Origin: null on the password form, which fails Rails' CSRF origin check.
  def set_private_headers
    response.headers["Referrer-Policy"] = "same-origin"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Cache-Control"] = "no-store"
  end

  def set_ticket
    @ticket = Ticket.find_by(share_token: params[:token].to_s) if params[:token].present?
    render :missing, status: :not_found unless @ticket
  end

  def require_unlocked
    return if !@ticket.share_password? || unlocked?

    if action_name == "show"
      render :password
    else
      redirect_to shared_ticket_path(@ticket.share_token)
    end
  end

  # The session remembers a fingerprint of the password hash, so a new
  # password or a new link locks the page again.
  def unlock_key
    Digest::SHA256.hexdigest(@ticket.share_password_digest.to_s)[0, 16]
  end

  def unlocked?
    session.dig(:unlocked_shares, @ticket.share_token) == unlock_key
  end

  def remember_unlocked
    unlocked = (session[:unlocked_shares] || {}).to_h.except(@ticket.share_token)
    unlocked[@ticket.share_token] = unlock_key
    session[:unlocked_shares] = unlocked.to_a.last(UNLOCKED_LIMIT).to_h
  end
end
