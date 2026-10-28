require "test_helper"

# Plain text links (specs/markdown.md "Plain text links").
class TicketsHelperTest < ActionView::TestCase
  LONG = "https://www.linkedin.com/comm/in/some-person-123?lipi=urn%3Ali&midToken=AQE&trk=eml-digest&otpToken=#{"x" * 200}".freeze

  test "an address becomes a link with a short label and the full target" do
    html = Nokogiri::HTML5.fragment(ticket_text("View profile: #{LONG}\nBye"))
    link = html.at_css("a")
    assert_equal LONG, link["href"]
    assert_equal "linkedin.com/comm/in/some-person-123", link.text
    assert_equal "noopener noreferrer nofollow", link["rel"]
    assert_equal "_blank", link["target"]
    assert link.key?("data-address")
    assert_match(/\AView profile: linkedin\.com\S+\nBye\z/, html.text)
  end

  test "long paths are cut, trailing punctuation stays text, html stays escaped" do
    label = address_label("https://example.com/#{"a" * 80}")
    assert_equal 48, label.length
    assert label.end_with?("…")
    assert_equal "example.com", address_label("http://example.com/")

    html = ticket_text("See https://example.com/a. Or (https://example.com/b) <b>x</b>")
    assert_includes html, %(href="https://example.com/a">example.com/a</a>.)
    assert_includes html, 'href="https://example.com/b">example.com/b</a>)'
    assert_includes html, "&lt;b&gt;x&lt;/b&gt;"
    assert_includes ticket_text("https://en.wikipedia.org/wiki/Foo_(bar)"), %(href="https://en.wikipedia.org/wiki/Foo_(bar)")
  end

  test "no links for other schemes, and a quote cannot break out of the attribute" do
    html = ticket_text(%(javascript:alert(1) ftp://example.com https://example.com/"onmouseover="x))
    assert_equal 1, Nokogiri::HTML5.fragment(html).css("a").size
    assert_includes html, %(href="https://example.com/")
    assert_not_includes html, %(onmouseover="x")
  end

  MAIL = <<~TEXT
    Hello,
    > earlier words
    > more
    Thanks
    -----
    Middle
    https://example.com/x?trk=1
    ----------------------------------------
    This email was intended for you.
    Unsubscribe: https://example.com/u
    --#{" "}
    Ann
  TEXT

  test "mail is laid out as mail: rules, quotes, footer and signature, nothing left out" do
    html = Nokogiri::HTML5.fragment(mail_text(MAIL))
    assert_equal "earlier words\nmore", html.at_css("blockquote.mail-quote").text
    assert_equal 1, html.css("hr.mail-rule").size, "the last rule starts the footer"
    assert_match(/This email was intended for you\.\nUnsubscribe: example\.com\/u/, html.at_css(".mail-footer").text)
    assert_equal "Ann", html.at_css(".mail-signature").text
    %w[Hello Thanks Middle].each { |word| assert_includes html.text, word }
    assert_equal "https://example.com/x?trk=1", html.css("a").first["href"]
  end

  OUTLOOK = <<~TEXT
    Ich kann die Seite nicht öffnen.

    ________________________________
    From: desk@example.com <desk@example.com>
    Sent: Wednesday, October 28, 2026 12:17
    To: Ann <ann@example.com>
    Subject: [Stopan #1009] New reply: Printer

    Hello Ann,
    We are working on it.

    -----Original Message-----
    Von: Ann <ann@example.com>
    Gesendet: Mittwoch, 28. Oktober 2026 11:00
    Betreff: Printer

    The printer is broken.
  TEXT

  test "earlier messages quoted without > are nested, collapsible sections" do
    html = Nokogiri::HTML5.fragment(mail_text(OUTLOOK))
    outer = html.at_css("details.mail-quoted")
    assert_not outer.key?("open"), "closed below the reply's own text"
    assert_equal "Earlier message from desk@example.com, Wednesday, October 28, 2026 12:17", outer.at_css("> summary").text
    assert_match(/Subject: \[Stopan #1009\]/, outer.at_css("> .mail-quoted__headers").text)
    inner = outer.at_css(".mail-quoted__body details.mail-quoted")
    assert_equal "Earlier message from Ann, Mittwoch, 28. Oktober 2026 11:00", inner.at_css("> summary").text
    assert_includes inner.at_css(".mail-quoted__body").text, "The printer is broken."
    assert_includes inner["class"], "mail-quoted--1"
    assert_equal 0, html.css("hr.mail-rule").size, "the rule before the header belongs to the earlier message"
    assert_includes html.children.first.text, "Ich kann die Seite nicht öffnen."
  end

  test "a forward that starts with the earlier message is open; > quotes nest by level" do
    html = Nokogiri::HTML5.fragment(mail_text("---------- Forwarded message ---------\nFrom: Bob <bob@example.com>\nDate: Mon\nSubject: Hi\n\nBody"))
    assert html.at_css("details.mail-quoted[open]")
    assert_equal "Earlier message from Bob, Mon", html.at_css("summary").text

    html = Nokogiri::HTML5.fragment(mail_text("Reply\n> first\n>> second\n> again"))
    outer = html.at_css("blockquote.mail-quote--0")
    assert_equal "second", outer.at_css("blockquote.mail-quote--1").text.strip
    assert_includes outer.text, "again"

    html = Nokogiri::HTML5.fragment(mail_text("From: someone in the text\nno header block here"))
    assert_nil html.at_css("details"), "a From line alone is not an earlier message"
  end

  test "the request's copy header has the ticket's facts; staff also see emails and mail headers" do
    ticket = tickets(:printer)
    ticket.update_columns(mail_headers: { "from" => [ "Anna <anna@example.com>" ], "to" => [ "desk@example.com" ] })
    define_singleton_method(:current_user) { users(:agent) }
    header = ticket_copy_header(ticket)
    lines = header.lines.map(&:chomp)
    assert_equal "#1001 #{ticket.subject}", lines.first
    assert_includes lines, "Status: #{status_name(ticket.status)}"
    assert_includes lines, "Priority: #{priority_name(ticket.priority)}"
    assert_includes lines, "Requester: #{users(:anna).display_name} <#{users(:anna).email}>"
    assert_includes lines, "Organization: Acme Bakery"
    assert_includes lines, "Link: #{ticket_url(ticket)}"
    assert_includes lines, "From: Anna <anna@example.com>"

    define_singleton_method(:current_user) { users(:anna) }
    assert_not_includes ticket_copy_header(ticket), "From:"
    assert_not_includes ticket_copy_header(ticket), users(:anna).email

    ticket.share!(actor: users(:agent))
    shared = ticket_copy_header(ticket, shared: true).lines.map(&:chomp)
    assert_equal [ "#1001 #{ticket.subject}", "Status: #{status_name(ticket.status)}", "Link: #{shared_ticket_url(ticket.share_token)}" ], shared
  end

  test "the layout follows the source of the message" do
    ticket = tickets(:printer)
    ticket.update_columns(description: "Hi\n-----\nfooter", source: "email")
    assert_includes formatted_text(ticket), "mail-footer"
    ticket.update_columns(source: "app")
    assert_not_includes formatted_text(ticket), "mail-footer"
  end
end
