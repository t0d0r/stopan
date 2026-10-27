# Renders message text written in Markdown (specs/markdown.md; taken from
# g0no). GitHub flavoured: tables, task lists, strikethrough, autolinks.
# Raw HTML in the text is dropped by the renderer, the result goes through
# Rails' sanitizer with a small allow-list, and links open in a new tab
# without a referrer. Images are not allowed, so a message cannot load
# content from other sites.
module MarkdownHelper
  MARKDOWN_OPTIONS = {
    parse: { smart: false },
    render: { unsafe: false, hardbreaks: true },
    extension: { table: true, tasklist: true, strikethrough: true, autolink: true, header_ids: nil, footnotes: false }
  }.freeze

  MARKDOWN_TAGS = %w[h1 h2 h3 h4 h5 h6 p br hr strong em del code pre blockquote ul ol li a
                     table thead tbody tr th td input].freeze
  MARKDOWN_ATTRIBUTES = %w[href type checked disabled align start].freeze

  def render_markdown(text)
    html = Commonmarker.to_html(text.to_s, options: MARKDOWN_OPTIONS, plugins: { syntax_highlighter: nil })
    html = sanitize(html, tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a").each do |link|
      link.remove_attribute("href") if link["href"].blank?
      link["rel"] = "noopener noreferrer nofollow"
      link["target"] = "_blank"
    end
    fragment.css("input").each do |input|
      next input.remove unless input["type"] == "checkbox"

      input["disabled"] = "disabled"
    end
    fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety
  end
end
