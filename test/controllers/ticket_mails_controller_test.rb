require "test_helper"

# The sealed frame with the mail's HTML (specs/organization-mail.md "HTML view").
class TicketMailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = tickets(:printer)
    @ticket.update_columns(mail_html: %(<p class="hi">Hello <img src="https://example.com/p.gif"></p>))
  end

  test "the frame document has its own strict policy and no scripts" do
    sign_in users(:agent)
    get ticket_mail_url(@ticket)
    assert_response :success
    policy = response.headers["Content-Security-Policy"]
    assert_includes policy, "default-src 'none'"
    assert_includes policy, "img-src data:;"
    assert_includes policy, "frame-ancestors 'self'"
    assert_includes policy, "sandbox allow-popups allow-popups-to-escape-sandbox allow-same-origin"
    assert_not_includes policy, "allow-scripts"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.body, %(<p class="hi">Hello)
    assert_not_includes response.body, "<script"

    get ticket_mail_url(@ticket, images: 1)
    assert_includes response.headers["Content-Security-Policy"], "img-src data: https: http:;"
  end

  test "only for who may see the ticket, and only when there is HTML" do
    sign_in users(:anna)
    get ticket_mail_url(@ticket)
    assert_response :success

    sign_in users(:boris)
    get ticket_mail_url(@ticket)
    assert_response :not_found

    sign_in users(:agent)
    get ticket_mail_url(tickets(:vpn))
    assert_response :not_found
  end

  test "the ticket page shows tabs, the frame and the blocked images bar" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#description [data-mail-view]" do
      assert_select "[data-mail-tabs][hidden] [data-mail-tab=html][aria-selected=true]", "HTML"
      assert_select "iframe.mail-frame[src=?][sandbox='allow-popups allow-popups-to-escape-sandbox allow-same-origin'][referrerpolicy=no-referrer]",
                    ticket_mail_path(@ticket)
      assert_select ".mail-view__images a[href=?]", ticket_path(@ticket, mail_images: 1, anchor: "description"), "Show images"
    end
    assert_select "#mail-pane-text [data-message-text]"

    get ticket_url(@ticket, mail_images: 1)
    assert_select "iframe.mail-frame[src=?]", ticket_mail_path(@ticket, images: 1)
    assert_select ".mail-view__images", 0

    get ticket_url(tickets(:old_question))
    assert_select "[data-mail-view]", 0
  end
end
