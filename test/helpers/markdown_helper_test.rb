require "test_helper"

# Sanitized Markdown rendering (specs/markdown.md "Rendering").
class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "formats GitHub flavoured Markdown" do
    html = render_markdown("# Title\n\n**bold** *it* ~~old~~ `code`\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nline one\nline two")
    assert_includes html, "<h1>Title</h1>"
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<del>old</del>"
    assert_includes html, "<code>code</code>"
    assert_includes html, "<table>"
    assert_includes html, "line one<br>"
  end

  test "drops raw HTML, scripts, images and unsafe links" do
    html = render_markdown("<script>alert(1)</script>\n\n<b onclick=x>hi</b>\n\n![x](https://tracker.example/p.gif)\n\n" \
                           "[bad](javascript:alert(1)) <img src=x onerror=alert(1)>")
    assert_not_includes html, "<script"
    assert_not_includes html, "onclick"
    assert_not_includes html, "<img"
    assert_not_includes html, "onerror"
    assert_not_includes html, "javascript:"
    assert_not_includes html, "tracker.example"
  end

  test "links open in a new tab without a referrer; check boxes are disabled" do
    html = render_markdown("<https://example.com> and [docs](https://example.com/docs)\n\n- [ ] todo\n- [x] done")
    assert_equal 2, html.scan('rel="noopener noreferrer nofollow" target="_blank"').size
    assert_equal 2, html.scan('disabled="disabled"').size
    assert_includes html, 'checked=""'
  end
end
