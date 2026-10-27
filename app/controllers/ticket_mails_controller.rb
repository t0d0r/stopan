# The cleaned HTML of the mail a ticket came from, as a document of its
# own for the sealed frame on the ticket page (specs/organization-mail.md
# "HTML view"): its own Content-Security-Policy lets no script run and
# nothing outside load, unless remote images were asked for.
class TicketMailsController < ApplicationController
  content_security_policy false

  def show
    ticket = find_visible_ticket(params[:ticket_id])
    raise ActiveRecord::RecordNotFound if ticket.mail_html.blank?

    images = params[:images] == "1" ? " https: http:" : ""
    response.headers["Content-Security-Policy"] =
      "default-src 'none'; style-src 'unsafe-inline'; img-src data:#{images}; font-src data:; " \
      "frame-ancestors 'self'; base-uri 'none'; form-action 'none'; " \
      "sandbox allow-popups allow-popups-to-escape-sandbox allow-same-origin"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "private, no-store"
    render html: document(ticket.mail_html), layout: false
  end

  private

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
