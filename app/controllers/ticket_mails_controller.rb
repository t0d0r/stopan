# The cleaned HTML of the mail a ticket or a reply came from, as a
# document of its own for the sealed frame on the ticket page
# (specs/organization-mail.md "HTML view"): its own
# Content-Security-Policy lets no script run and nothing outside load,
# unless remote images were asked for. Inline images of the mail come
# from the message's own files ("Replies and inline images").
class TicketMailsController < ApplicationController
  include FileSending

  content_security_policy false
  before_action :set_message

  def show
    raise ActiveRecord::RecordNotFound if @message.mail_html.blank?

    remote = params[:images] == "1" ? " https: http:" : ""
    response.headers["Content-Security-Policy"] =
      "default-src 'none'; style-src 'unsafe-inline'; img-src data: #{request.base_url}#{images_path}#{remote}; " \
      "font-src data:; frame-ancestors 'self'; base-uri 'none'; form-action 'none'; " \
      "sandbox allow-popups allow-popups-to-escape-sandbox allow-same-origin"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "private, no-store"
    render html: document(with_inline_images(@message.mail_html)), layout: false
  end

  # One inline image of the mail: an image file of this very message.
  def image
    attachment = inline_files.find { |file| file.id.to_s == params[:id].to_s }
    raise ActiveRecord::RecordNotFound unless attachment

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    response.headers["Cache-Control"] = "private, max-age=3600"
    send_blob(attachment.blob, disposition: "inline")
  end

  private

  # The ticket, or one of its replies the user may see.
  def set_message
    @ticket = find_ticket_for_page(params[:ticket_id])
    @message = params[:comment_id] ? Comment.visible_to(current_user).where(ticket: @ticket).find(params[:comment_id]) : @ticket
  end

  def images_path
    comment = @message if @message.is_a?(Comment)
    comment ? "/tickets/#{@ticket.number}/comments/#{comment.id}/mail/images/" : "/tickets/#{@ticket.number}/mail/images/"
  end

  def inline_files
    @inline_files ||= @message.files.attachments.includes(:blob).select do |file|
      MailHtml::INLINE_TYPES.include?(file.blob.content_type) && file.blob.metadata["content_id"].present?
    end
  end

  def with_inline_images(html)
    MailHtml.inline_images(html) do |content_id|
      file = inline_files.find { |candidate| candidate.blob.metadata["content_id"] == content_id }
      "#{images_path}#{file.id}" if file
    end
  end

  # A white page like a mail program's message frame, with the mail's own
  # styles after these. The HTML was cleaned when the mail came in.
  def document(html)
    <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
      <!doctype html>
      <html><head><meta charset="utf-8"><title>#{ERB::Util.h(t("ui.mail_view.frame_title"))}</title>
      <style>
        html { background: #fff; color: #222; }
        body { margin: 0; padding: 14px 16px; font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; overflow-wrap: anywhere; }
        img { max-width: 100%; height: auto; }
        table { max-width: 100%; }
        a { color: #0a64d6; }
      </style></head>
      <body>#{html}</body></html>
    HTML
  end
end
