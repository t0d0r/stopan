require "test_helper"

# specs/webhooks.md
class WebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def webhook(organization = organizations(:acme), events: Webhook::EVENTS, url: "https://hooks.example.com/stopan")
    organization.webhooks.create!(url: url, event_names: events)
  end

  def deliveries
    enqueued_jobs.select { |job| job["job_class"] == "WebhookDeliveryJob" }.map { |job| [ job["arguments"][1], JSON.parse(job["arguments"][2]) ] }
  end

  test "a webhook gets a secret, stored encrypted, and needs an https URL and an event" do
    hook = webhook
    assert_match(/\Awhsec_[1-9A-HJ-NP-Za-km-z]{40}\z/, hook.secret)
    stored = Webhook.connection.select_value("SELECT secret FROM webhooks WHERE id = #{hook.id}")
    assert_not_includes stored, hook.secret

    organization = organizations(:acme)
    assert_not organization.webhooks.new(url: "http://hooks.example.com/", event_names: Webhook::EVENTS).valid?
    assert_not organization.webhooks.new(url: "https://u:p@hooks.example.com/", event_names: Webhook::EVENTS).valid?
    assert_not organization.webhooks.new(url: "https://hooks.example.com/#{'a' * 500}", event_names: Webhook::EVENTS).valid?
    assert_not organization.webhooks.new(url: "https://hooks.example.com/", event_names: []).valid?
    assert_not organization.webhooks.new(url: "https://hooks.example.com/", event_names: %w[note.created]).valid?
    assert_includes organization.webhooks.new(url: "http://x.example/", event_names: Webhook::EVENTS).tap(&:valid?).errors.full_messages.first,
                    "must start with https://"
  end

  test "an organization has at most five webhooks" do
    Webhook::LIMIT.times { |i| webhook(url: "https://hooks.example.com/#{i}") }
    extra = organizations(:acme).webhooks.new(url: "https://hooks.example.com/x", event_names: Webhook::EVENTS)
    assert_not extra.valid?
    assert_match(/at most 5 webhooks/, extra.errors.full_messages.to_sentence)
  end

  test "a new ticket queues ticket.created for the organization's active webhooks that want it" do
    both = webhook
    replies_only = webhook(events: %w[reply.created], url: "https://hooks.example.com/replies")
    off = webhook(url: "https://hooks.example.com/off").tap { |hook| hook.update!(active: false) }
    other = webhook(organizations(:globex), url: "https://hooks.example.com/globex")

    ticket = Ticket.create!(subject: "Screen flickers", description: "Since Monday", requester: users(:anna),
                            organization: organizations(:acme), actor: users(:anna))
    jobs = enqueued_jobs.select { |job| job["job_class"] == "WebhookDeliveryJob" }
    assert_equal [ both.id ], jobs.map { |job| job["arguments"][0] }
    name, body = deliveries.sole
    assert_equal "ticket.created", name
    assert_equal "ticket.created", body["event"]
    assert_equal ticket.number, body.dig("ticket", "number")
    assert_equal "Since Monday", body.dig("ticket", "description")
    assert_equal organizations(:acme).name, body.dig("organization", "name")
    assert_equal users(:anna).display_name, body.dig("ticket", "requester", "name")
    assert_nil body["reply"]
    assert_match(/\A[0-9a-f-]{36}\z/, body["delivery"])
    assert [ replies_only, off, other ].all?(&:persisted?)
  end

  test "a public reply queues reply.created; an internal note and a status change queue nothing" do
    webhook
    ticket = tickets(:printer)
    clear_enqueued_jobs

    ticket.add_comment(author: users(:agent), body: "STAFF-ONLY thoughts", internal: true)
    ticket.apply_changes({ priority: "high" }, actor: users(:agent))
    assert_empty deliveries

    comment = ticket.add_comment(author: users(:agent), body: "Please restart it.")
    name, body = deliveries.sole
    assert_equal "reply.created", name
    assert_equal comment.id, body.dig("reply", "id")
    assert_equal "Please restart it.", body.dig("reply", "body")
    assert_equal({ "id" => users(:agent).id, "name" => users(:agent).display_name, "role" => "agent" }, body.dig("reply", "author"))
  end

  test "the body never carries internal notes or email addresses" do
    webhook
    ticket = tickets(:printer)
    ticket.add_comment(author: users(:agent), body: "STAFF-ONLY secret", internal: true)
    clear_enqueued_jobs
    ticket.add_comment(author: users(:anna), body: "Thanks")
    text = enqueued_jobs.select { |job| job["job_class"] == "WebhookDeliveryJob" }.map { |job| job["arguments"][2] }.join
    assert_not_includes text, "STAFF-ONLY"
    assert_no_match(/[\w.+-]+@[\w-]+\.\w+/, text)
    User.pluck(:email).each { |email| assert_not_includes text, email }
  end

  test "long text is cut" do
    hook = webhook
    ticket = tickets(:printer)
    ticket.update_columns(description: "x" * 30_000)
    assert_equal Webhook::TEXT_LIMIT, hook.payload("ticket.created", ticket: ticket).dig(:ticket, :description).length
  end

  test "deleting the organization's webhooks goes with the organization" do
    organization = Organization.create!(name: "Shortlived")
    webhook(organization)
    assert_difference("Webhook.count", -1) { organization.destroy! }
  end
end
