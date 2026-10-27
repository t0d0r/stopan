class ApplicationMailer < ActionMailer::Base
  # The same sender as Devise's emails (specs/notifications.md).
  default from: -> { Devise.mailer_sender }
  layout "mailer"

  after_action :route_through_organization

  private

  # The organization whose SMTP, From and Reply-To a message uses
  # (specs/organization-mail.md "Outgoing mail"): the one set by the mailer,
  # the ticket's, or the user's only organization with SMTP; else nil and
  # the global settings apply.
  def mail_organization
    return @organization if @organization
    return @ticket.organization if @ticket

    candidates = @resource.respond_to?(:organizations) ? @resource.organizations.select(&:smtp_ready?) : []
    candidates.first if candidates.one?
  end

  def route_through_organization
    return unless @_mail_was_called

    organization = mail_organization
    # A Google account that cannot give a token falls back to the global
    # SMTP, like a broken password (specs/mail-oauth.md "Failure").
    settings = begin
      organization.smtp_settings if organization&.smtp_ready?
    rescue GoogleOauth::Error => e
      Rails.logger.warn("Organization #{organization.id}: Google mail sign-in failed: #{e.message}")
      nil
    end
    if settings
      message.from = organization.mail_from
      wrap_delivery_behavior!(delivery_method, settings)
    end
    message.reply_to = organization.mailbox_address if organization&.imap_enabled? && organization.mailbox_address
    # Without any SMTP (production without SMTP_ADDRESS) the message is
    # dropped instead of trying a local mail server.
    message.perform_deliveries = false unless settings || Rails.configuration.x.global_smtp != false
  end
end
