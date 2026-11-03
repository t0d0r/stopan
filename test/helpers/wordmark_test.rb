require "test_helper"

# The STOPAN wordmark (specs/ui.md "Logo").
class WordmarkTest < ActionView::TestCase
  include ApplicationHelper

  test "the wordmark is one static path in the theme's ink, decorative" do
    svg = Nokogiri::HTML5.fragment(wordmark).at_css("svg.wordmark")
    assert_equal [ "0 0 818 137", "currentColor", "true", "84", "14" ],
                 [ svg["viewBox"], svg["fill"], svg["aria-hidden"], svg["width"], svg["height"] ]
    assert_equal 1, svg.css("path").size
    assert_empty svg.css("script, style, a, image, use, foreignObject")
    assert_no_match(/href|on[a-z]+=/i, ApplicationHelper::WORDMARK)
    assert_equal "167", Nokogiri::HTML5.fragment(wordmark(height: 28)).at_css("svg")["width"]
  end
end
