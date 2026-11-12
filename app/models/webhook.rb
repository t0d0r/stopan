require "openssl"

# An HTTP call to another system when a ticket is opened or publicly
# answered in one organization (specs/webhooks.md). Internal notes and
# email addresses never leave.
class Webhook < ApplicationRecord
  EVENTS = %w[ticket.created reply.created].freeze
  # Ticket event action => webhook event.
  ACTIONS = { "created" => "ticket.created", "replied" => "reply.created" }.freeze
  LIMIT = 5
  MAX_FAILURES = 20
  TEXT_LIMIT = 20_000

  belongs_to :organization
  encrypts :secret

  normalizes :url, with: ->(url) { url.to_s.strip }

  validates :url, presence: true, length: { maximum: 500 }
  validate :url_allowed
  validate :events_chosen
  validate :within_limit, on: :create

  before_validation(on: :create) { self.secret ||= "whsec_#{SecureRandom.base58(40)}" }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:created_at, :id) }
  # Failing now, or switched off after failing (specs/status.md "Webhooks").
  scope :problems, -> { where("webhooks.failures > 0").order(:organization_id, :id) }

  # Queues a delivery for each active webhook of the ticket's
  # organization that wants one of these events. Called by TicketNotifier
  # once the change is committed.
  def self.notify(ticket, events)
    wanted = events.filter_map { |event| [ ACTIONS[event.action], event ] if ACTIONS.key?(event.action) && !event.internal? }
    return if wanted.empty?

    active.where(organization_id: ticket.organization_id).ordered.each do |webhook|
      wanted.each do |name, event|
        webhook.deliver_later(name, ticket: ticket, comment: event.comment) if webhook.event_names.include?(name)
      end
    end
  end

  def event_names
    events.to_s.split
  end

  def event_names=(names)
    self.events = (Array(names).map(&:to_s) & EVENTS).join(" ")
  end

  def deliver_later(name, ticket: nil, comment: nil)
    WebhookDeliveryJob.perform_later(id, name, JSON.generate(payload(name, ticket: ticket, comment: comment)))
  end

  # The "Send test" button.
  def ping!
    deliver_later("ping")
  end

  # What the receiver gets: what the requester sees on the ticket, with
  # names and ids but no email addresses.
  def payload(name, ticket: nil, comment: nil)
    body = { event: name, delivery: SecureRandom.uuid, sent_at: Time.current.utc.iso8601,
             organization: { id: organization.id, name: organization.name } }
    body[:ticket] = ticket_payload(ticket) if ticket
    body[:reply] = reply_payload(comment) if comment && !comment.internal?
    body
  end

  def sign(body)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
  end

  # One delivery ended: remember it, and switch off after too many
  # failures in a row.
  def record_result(status: nil, error: nil)
    ok = error.nil? && status.to_i.between?(200, 299)
    failed = ok ? 0 : failures + 1
    update_columns(last_status: status, last_error: (ok ? nil : (error || "HTTP #{status}")).to_s.first(200).presence,
                   last_sent_at: Time.current, failures: failed, active: active && failed < MAX_FAILURES,
                   updated_at: Time.current)
    ok
  end

  private

  def ticket_payload(ticket)
    { number: ticket.number, reference: ticket.reference, subject: ticket.subject,
      description: ticket.description.to_s.first(TEXT_LIMIT), status: ticket.status, priority: ticket.priority,
      source: ticket.source, requester: person(ticket.requester), assignee: person(ticket.assignee),
      created_at: ticket.created_at.utc.iso8601,
      url: Rails.application.routes.url_helpers.ticket_url(ticket, **Rails.application.config.action_mailer.default_url_options) }
  end

  def reply_payload(comment)
    { id: comment.id, body: comment.body.to_s.first(TEXT_LIMIT), source: comment.source, author: person(comment.author),
      created_at: comment.created_at.utc.iso8601 }
  end

  def person(user)
    user && { id: user.id, name: user.display_name, role: user.role }
  end

  def url_allowed
    return if url.blank?

    reason = WebhookSender.refusal(url)
    errors.add(:url, reason) if reason
  end

  def events_chosen
    errors.add(:events, :blank) if event_names.empty? || (event_names - EVENTS).any?
  end

  def within_limit
    errors.add(:base, :too_many_webhooks, count: LIMIT) if organization && organization.webhooks.count >= LIMIT
  end
end
