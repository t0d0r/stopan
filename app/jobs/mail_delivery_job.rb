# Sends the queued emails and tries again when a delivery fails: 5 attempts
# with growing waits, then the job stays in the queue's failed list
# (specs/notifications.md "Delivery"). Emails to the customer side never
# get here twice: TicketMailer records their failure and does not raise.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
end
