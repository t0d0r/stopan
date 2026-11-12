require "test_helper"
require "socket"

# specs/webhooks.md "Delivery", against a real server on 127.0.0.1.
class WebhookDeliveryJobTest < ActiveJob::TestCase
  setup do
    WebhookSender.allow_local = true
    @requests = Queue.new
    @server = TCPServer.new("127.0.0.1", 0)
    @answer = "200 OK"
    @thread = Thread.new do
      loop do
        client = @server.accept
        head = +""
        head << client.gets until head.end_with?("\r\n\r\n")
        body = client.read(head[/content-length: (\d+)/i, 1].to_i)
        @requests << [ head, body ]
        extra = @answer.start_with?("302") ? "Location: http://127.0.0.1:#{@server.addr[1]}/elsewhere\r\n" : ""
        client.write "HTTP/1.1 #{@answer}\r\n#{extra}Content-Length: 2\r\nConnection: close\r\n\r\nok"
        client.close
      end
    rescue IOError, Errno::EBADF
      nil
    end
    @webhook = organizations(:acme).webhooks.create!(url: "http://127.0.0.1:#{@server.addr[1]}/hook", event_names: Webhook::EVENTS)
  end

  teardown do
    WebhookSender.allow_local = false
    @server.close
    @thread.join(1)
  end

  def deliver(name = "ping", **options)
    body = JSON.generate(@webhook.payload(name, **options))
    WebhookDeliveryJob.perform_now(@webhook.id, name, body)
    body
  end

  test "a delivery posts the signed body and records the success" do
    body = deliver("ticket.created", ticket: tickets(:printer))
    head, received = @requests.pop
    assert_match %r{\APOST /hook HTTP/1\.1}, head
    assert_equal body, received
    assert_match(/^x-stopan-event: ticket\.created\r$/i, head)
    assert_match(/^x-stopan-delivery: #{JSON.parse(body)["delivery"]}\r$/i, head)
    assert_match(/^content-type: application\/json\r$/i, head)
    signature = head[/^x-stopan-signature: (\S+)\r$/i, 1]
    assert_equal "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @webhook.secret, received)}", signature
    assert_not_equal "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'whsec_other', received)}", signature

    @webhook.reload
    assert_equal 200, @webhook.last_status
    assert_nil @webhook.last_error
    assert_equal 0, @webhook.failures
    assert @webhook.last_sent_at.present?
  end

  test "a failed delivery is recorded and tried again; a success clears the count" do
    @answer = "500 Internal Server Error"
    assert_enqueued_jobs 1, only: WebhookDeliveryJob do
      deliver
    end
    @webhook.reload
    assert_equal 500, @webhook.last_status
    assert_equal "HTTP 500", @webhook.last_error
    assert_equal 1, @webhook.failures
    assert @webhook.active?

    @answer = "204 No Content"
    deliver
    assert_equal [ 204, 0, nil ], @webhook.reload.values_at(:last_status, :failures, :last_error)
  end

  test "a redirect is a failure and is not followed" do
    @answer = "302 Found"
    deliver
    assert_equal 1, @requests.size
    assert_equal "HTTP 302", @webhook.reload.last_error
  end

  test "a refused connection and an address that is not allowed are failures" do
    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    @webhook.update_columns(url: "http://127.0.0.1:#{port}/")
    deliver
    assert_equal "connection refused", @webhook.reload.last_error
    assert_nil @webhook.last_status

    WebhookSender.allow_local = false
    @webhook.update_columns(url: "https://127.0.0.1:#{@server.addr[1]}/")
    deliver
    assert_equal "address not allowed", @webhook.reload.last_error
    assert_equal 0, @requests.size
  end

  test "twenty failures in a row switch the webhook off, and it then sends nothing" do
    @answer = "500 Internal Server Error"
    @webhook.update_columns(failures: Webhook::MAX_FAILURES - 1)
    deliver
    assert_not @webhook.reload.active?
    assert_equal Webhook::MAX_FAILURES, @webhook.failures

    @requests.clear
    assert_no_enqueued_jobs { deliver }
    assert_equal 0, @requests.size
  end

  test "a deleted webhook sends nothing" do
    body = JSON.generate(@webhook.payload("ping"))
    id = @webhook.id
    @webhook.destroy!
    WebhookDeliveryJob.perform_now(id, "ping", body)
    assert_equal 0, @requests.size
  end
end
