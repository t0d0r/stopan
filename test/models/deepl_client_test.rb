require "test_helper"
require "socket"

# The DeepL request and its errors (specs/translation.md), against a local
# one-request HTTP server: no network.
class DeeplClientTest < ActiveSupport::TestCase
  def with_server(status: "200 OK", body: "")
    server = TCPServer.new("127.0.0.1", 0)
    request = nil
    thread = Thread.new do
      client = server.accept
      head = +""
      while (line = client.gets) && line != "\r\n"
        head << line
      end
      request = head + "\r\n" + client.read(head[/content-length: (\d+)/i, 1].to_i)
      client.write "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      client.close
    end
    yield "http://127.0.0.1:#{server.addr[1]}"
    thread.join(5)
    request
  ensure
    server&.close
  end

  test "sends the text with the target code and the key, and reads the result" do
    answer = { translations: [ { detected_source_language: "DE", text: "Привет" } ] }.to_json
    result = nil
    request = with_server(body: answer) do |url|
      result = DeeplClient.new(key: "secret-key", base_url: url).translate("Hallo", target: "bg")
    end
    assert_equal [ "Привет", "de" ], result
    assert_match %r{\APOST /v2/translate HTTP/1.1}, request
    assert_match(/^Authorization: DeepL-Auth-Key secret-key\r$/i, request)
    body = JSON.parse(request.split("\r\n\r\n", 2).last)
    assert_equal({ "text" => [ "Hallo" ], "target_lang" => "BG" }, body)

    request = with_server(body: answer) { |url| DeeplClient.new(key: "k", base_url: url).translate("x", target: "en") }
    assert_equal "EN-GB", JSON.parse(request.split("\r\n\r\n", 2).last)["target_lang"]
  end

  test "free keys use the free host, others the pro host" do
    assert_equal "https://api-free.deepl.com", DeeplClient.new(key: "abc:fx", base_url: nil).base_url
    assert_equal "https://api.deepl.com", DeeplClient.new(key: "abc", base_url: nil).base_url
  end

  test "errors, refused connections and a missing key raise DeeplClient::Error without the key" do
    error = assert_raises(DeeplClient::Error) do
      with_server(status: "403 Forbidden", body: "{}") { |url| DeeplClient.new(key: "secret-key", base_url: url).translate("x", target: "de") }
    end
    assert_no_match(/secret-key/, error.message)

    with_server(body: "not json") do |url|
      assert_raises(DeeplClient::Error) { DeeplClient.new(key: "k", base_url: url).translate("x", target: "de") }
    end

    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    assert_raises(DeeplClient::Error) { DeeplClient.new(key: "k", base_url: "http://127.0.0.1:#{port}").translate("x", target: "de") }
    assert_raises(DeeplClient::Error) { DeeplClient.new(key: "", base_url: nil).translate("x", target: "de") }
  end
end
