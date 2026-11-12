require "test_helper"

# specs/webhooks.md "Which addresses are allowed"
class WebhookSenderTest < ActiveSupport::TestCase
  teardown { WebhookSender.allow_local = false }

  test "only https URLs without credentials may be webhooks" do
    assert_nil WebhookSender.refusal("https://hooks.example.com/stopan?x=1")
    assert_equal :not_https, WebhookSender.refusal("http://hooks.example.com/")
    assert_equal :credentials, WebhookSender.refusal("https://user:pw@hooks.example.com/")
    [ "ftp://example.com/", "hooks.example.com", "https://", "javascript:alert(1)", "https://exa mple.com/", "" ].each do |url|
      assert_equal :invalid, WebhookSender.refusal(url), url
    end
  end

  test "addresses inside the network are not public" do
    %w[127.0.0.1 127.9.9.9 10.1.2.3 172.16.0.1 172.31.255.255 192.168.1.1 169.254.169.254 100.64.0.1 0.0.0.0 224.0.0.1
       ::1 :: fe80::1 fc00::1 fd12:3456::1 ::ffff:127.0.0.1 ::ffff:10.0.0.1 64:ff9b::7f00:1 nonsense].each do |address|
      assert_not WebhookSender.public_address?(address), address
    end
    %w[8.8.8.8 1.1.1.1 172.32.0.1 2606:4700:4700::1111].each do |address|
      assert WebhookSender.public_address?(address), address
    end
  end

  test "a host is refused when it is, or resolves to, an address inside the network" do
    %w[127.0.0.1 10.0.0.5 [::1] 169.254.169.254 localhost].each do |host|
      error = assert_raises(WebhookSender::Refused) { WebhookSender.resolve(host) }
      assert_equal "address not allowed", error.message, host
    end
    assert_equal "8.8.8.8", WebhookSender.resolve("8.8.8.8")

    resolver = Resolv.method(:getaddresses)
    Resolv.define_singleton_method(:getaddresses) { |_name| [ "93.184.216.34", "10.0.0.7" ] }
    assert_raises(WebhookSender::Refused) { WebhookSender.resolve("rebind.example.com") }
    Resolv.define_singleton_method(:getaddresses) { |_name| [] }
    assert_equal "address not found", assert_raises(WebhookSender::Refused) { WebhookSender.resolve("nowhere.example.com") }.message
  ensure
    Resolv.define_singleton_method(:getaddresses, resolver) if resolver
  end

  test "post refuses a URL that may not be called before any connection" do
    assert_raises(WebhookSender::Refused) { WebhookSender.post("http://127.0.0.1:9/", "{}", {}) }
    assert_raises(WebhookSender::Refused) { WebhookSender.post("https://127.0.0.1:9/", "{}", {}) }
  end
end
