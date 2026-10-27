require "net/http"

# The DeepL API (specs/translation.md). The key is the one stored on
# /admin/settings, else DEEPL_API_KEY; a key ending in ":fx" is a Free key
# with its own host. DEEPL_API_URL overrides the base URL.
class DeeplClient
  class Error < StandardError; end

  # DeepL's target codes for the UI languages; plain "EN" is deprecated.
  TARGETS = { "en" => "EN-GB", "bg" => "BG", "de" => "DE" }.freeze
  TIMEOUT = 10

  def self.configured?
    AppSetting.current.deepl_key.present?
  end

  attr_reader :base_url

  def initialize(key: AppSetting.current.deepl_key, base_url: ENV["DEEPL_API_URL"])
    @key = key.to_s
    @base_url = base_url.presence || (@key.end_with?(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com")
  end

  # Returns [translated text, detected source language in lower case].
  def translate(text, target:)
    raise Error, "no DEEPL_API_KEY" if @key.empty?

    uri = URI.join(@base_url, "/v2/translate")
    request = Net::HTTP::Post.new(uri, "Authorization" => "DeepL-Auth-Key #{@key}", "Content-Type" => "application/json")
    request.body = { text: [ text ], target_lang: TARGETS.fetch(target.to_s) }.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                   open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
    raise Error, "DeepL answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body).fetch("translations").first
    [ result.fetch("text"), result.fetch("detected_source_language").to_s.downcase ]
  rescue JSON::ParserError, KeyError, NoMethodError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise Error, "DeepL request failed (#{e.class})"
  end
end
