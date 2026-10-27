# Cleans the HTML part of an incoming mail for the sealed frame of the
# ticket page (specs/organization-mail.md "HTML view"). The frame's own
# Content-Security-Policy and sandbox are the main guard; this removes
# active content and unsafe targets before the HTML is stored.
module MailHtml
  MAX_BYTES = 1_000_000
  REMOVED = %w[script iframe frame frameset object embed applet form input button textarea select option
               base meta link noscript template].freeze
  LINK_SCHEMES = %w[http https mailto].freeze
  REMOTE_IMAGE = /<img\b[^>]*\bsrc\s*=\s*["']?\s*https?:|url\(\s*["']?\s*https?:/i

  # The cleaned document (the mail's styles and body), or nil when there
  # is nothing to show or it is too big.
  def self.clean(html)
    document = Nokogiri::HTML5.parse(html.to_s)
    document.css(REMOVED.join(", ")).each(&:remove)
    document.traverse do |node|
      next unless node.element?

      node.attribute_nodes.each { |attribute| attribute.remove if attribute.name.downcase.start_with?("on") }
    end
    document.css("a").each { |link| clean_link(link) }
    document.css("img").each { |image| clean_image(image) }
    document.css("[background]").each { |node| node.remove_attribute("background") unless remote_or_data?(node["background"]) }

    styles = document.css("head style").map(&:to_html).join("\n")
    body = document.at_css("body")&.inner_html.to_s
    return if body.strip.empty?

    cleaned = styles.empty? ? body : "#{styles}\n#{body}"
    cleaned if cleaned.bytesize <= MAX_BYTES
  end

  def self.remote_images?(html)
    html.to_s.match?(REMOTE_IMAGE)
  end

  def self.clean_link(link)
    href = link["href"].to_s.strip
    scheme = href[/\A([a-z][a-z0-9+.-]*):/i, 1]&.downcase
    if scheme && LINK_SCHEMES.include?(scheme)
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer nofollow"
    else
      link.remove_attribute("href")
    end
  end

  def self.clean_image(image)
    src = image["src"].to_s.strip
    image.remove_attribute("srcset")
    image.remove_attribute("src") unless src.match?(%r{\Ahttps?://}i) || src.match?(%r{\Adata:image/}i)
  end

  def self.remote_or_data?(value)
    value.to_s.strip.match?(%r{\A(https?://|data:image/)}i)
  end
  private_class_method :clean_link, :clean_image, :remote_or_data?
end
