require "test_helper"

# Cleaning the HTML part of a mail (specs/organization-mail.md "HTML view").
class MailHtmlTest < ActiveSupport::TestCase
  test "active content goes, layout and styles stay" do
    html = MailHtml.clean(<<~HTML)
      <html><head><style>.box { color: red }</style><meta http-equiv="refresh" content="0;url=https://evil.example"><script>alert(1)</script></head>
      <body onload="steal()"><table class="box" style="width: 600px"><tr><td onclick="x()">Hello</td></tr></table>
      <form action="https://evil.example"><input name="password"></form>
      <iframe src="https://evil.example"></iframe><svg><script>alert(2)</script></svg>
      <a href="javascript:alert(3)">bad</a> <a href="https://example.com/page">good</a> <a href="mailto:a@example.com">mail</a>
      <img src="cid:logo@x" alt="Logo"> <img src="https://example.com/pixel.gif"> <img src="data:image/png;base64,AAAA"></body></html>
    HTML
    doc = Nokogiri::HTML5.fragment(html)
    assert_includes html, ".box { color: red }"
    assert_includes html, %(style="width: 600px")
    assert_empty doc.css("script, meta, form, input, iframe")
    assert_no_match(/onload|onclick/, html)
    links = doc.css("a")
    assert_nil links[0]["href"]
    assert_equal [ "https://example.com/page", "_blank", "noopener noreferrer nofollow" ], [ links[1]["href"], links[1]["target"], links[1]["rel"] ]
    assert_equal "mailto:a@example.com", links[2]["href"]
    images = doc.css("img")
    assert_equal "cid:logo@x", images[0]["src"]  # an inline image, resolved when the frame is rendered
    assert_equal "Logo", images[0]["alt"]
    assert_equal "https://example.com/pixel.gif", images[1]["src"]
    assert images[2]["src"].start_with?("data:image/png")
    assert MailHtml.remote_images?(html)
  end

  test "a new ticket from a mail with an HTML part keeps it cleaned, the text stays the description" do
    org = organizations(:acme)
    org.update!(imap_enabled: true, imap_address: "imap.acme.example", imap_username: "desk", mailbox_address: "support@acme.example")
    mail = Mail.new do
      from "ivan@example.com"
      to "support@acme.example"
      subject "Newsletter"
      text_part { body "Plain words" }
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p style='color: blue'>Rich <b>words</b></p><script>alert(1)</script>"
      end
    end
    MailboxMessage.new(org, mail.to_s).process
    ticket = Ticket.order(:id).last
    assert_equal "Plain words", ticket.description
    assert_includes ticket.mail_html, "<b>words</b>"
    assert_includes ticket.mail_html, "color: blue"
    assert_not_includes ticket.mail_html, "script"
  end

  test "empty or huge mail is not kept" do
    assert_nil MailHtml.clean("<html><body>  </body></html>")
    assert_nil MailHtml.clean("<p>#{"x" * (MailHtml::MAX_BYTES + 1)}</p>")
    assert_not MailHtml.remote_images?("<p>no images</p>")
  end

  test "inline images are pointed at what the block returns, or lose their source" do
    html = %(<p>Hi</p><img src="cid:a@x" alt="A"><img src="CID:b@x" alt="B"><img src="https://example.com/c.png"><img src="cid:bad id">)
    asked = []
    result = MailHtml.inline_images(html) do |id|
      asked << id
      "/tickets/1/mail/images/7" if id == "a@x"
    end
    doc = Nokogiri::HTML5.fragment(result)
    assert_equal %w[a@x b@x], asked
    assert_equal [ "/tickets/1/mail/images/7", nil, "https://example.com/c.png" ], doc.css("img").first(3).map { |image| image["src"] }
    assert_equal "B", doc.css("img")[1]["alt"]
    plain = "<p>No inline images</p>"
    assert_same plain, MailHtml.inline_images(plain) { raise "not asked" }
  end
end
