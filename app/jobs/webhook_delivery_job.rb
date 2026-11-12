# One webhook request (specs/webhooks.md "Delivery"): tried 5 times with
# growing pauses, then given up. The body was built when the event
# happened, so every try sends the same one.
class WebhookDeliveryJob < ApplicationJob
  class Failed < StandardError; end

  retry_on Failed, wait: :polynomially_longer, attempts: 5 do |_job, _error|
    # Given up; the webhook already holds the last failure.
  end

  def perform(webhook_id, event, body)
    webhook = Webhook.active.find_by(id: webhook_id)
    return unless webhook

    status, error = send_request(webhook, event, body)
    raise Failed, error || "HTTP #{status}" unless webhook.record_result(status: status, error: error)
  end

  private

  def send_request(webhook, event, body)
    headers = { "Content-Type" => "application/json", "User-Agent" => "Stopan", "X-Stopan-Event" => event,
                "X-Stopan-Delivery" => JSON.parse(body)["delivery"].to_s, "X-Stopan-Signature" => webhook.sign(body) }
    [ WebhookSender.post(webhook.url, body, headers), nil ]
  rescue WebhookSender::Refused => e
    [ nil, e.message ]
  rescue Timeout::Error
    [ nil, "timeout" ]
  rescue SystemCallError => e
    # The plain name of the error ("connection refused"), without the
    # address Ruby puts in the message.
    [ nil, (e.class < SystemCallError ? e.class.new.message : "connection failed").downcase ]
  rescue OpenSSL::SSL::SSLError
    [ nil, "TLS error" ]
  rescue SocketError, IOError, Net::ProtocolError
    [ nil, "connection failed" ]
  end
end
