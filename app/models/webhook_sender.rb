require "net/http"
require "resolv"
require "ipaddr"

# Sends one webhook request (specs/webhooks.md "Which addresses are
# allowed"). The app makes the request from inside the server's network,
# so only https URLs on public addresses are called, and the request goes
# to the very address that was checked.
class WebhookSender
  class Refused < StandardError; end

  TIMEOUT = 5
  BLOCKED = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24
    192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 64:ff9b::/96 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32
  ].map { |range| IPAddr.new(range) }.freeze

  # Tests call a server on 127.0.0.1 over plain http; nothing else may.
  cattr_accessor :allow_local, default: false

  # Why a URL may not be a webhook, as an error key, or nil.
  def self.refusal(url)
    uri = URI.parse(url.to_s)
    return :invalid unless uri.is_a?(URI::HTTP) && uri.host.present?
    return :not_https unless uri.scheme == "https" || allow_local
    return :credentials if uri.userinfo.present?

    nil
  rescue URI::InvalidURIError
    :invalid
  end

  def self.public_address?(address)
    ip = IPAddr.new(address.to_s)
    ip = ip.native if ip.ipv4_mapped?
    BLOCKED.none? { |range| range.include?(ip) }
  rescue IPAddr::Error
    false
  end

  # The address to call for a host: its first address when all of them
  # are public, else Refused.
  def self.resolve(host)
    name = host.to_s.delete_prefix("[").delete_suffix("]")
    addresses = name.match?(/\A[\d.]+\z|:/) ? [ name ] : Resolv.getaddresses(name)
    raise Refused, "address not found" if addresses.empty?
    raise Refused, "address not allowed" unless allow_local || addresses.all? { |address| public_address?(address) }

    addresses.first
  end

  # POSTs the body and returns the HTTP status. Raises Refused for an
  # address that may not be called, and the usual network errors.
  def self.post(url, body, headers)
    raise Refused, "address not allowed" if refusal(url)

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = resolve(uri.host)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    http.write_timeout = TIMEOUT
    http.max_retries = 0
    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body
    # The answer's body is not wanted; redirects are not followed.
    http.start { |connection| connection.request(request) { |response| return response.code.to_i } }
  end
end
