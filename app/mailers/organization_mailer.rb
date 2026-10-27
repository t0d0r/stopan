# Mail about an organization's own settings (specs/organization-mail.md).
class OrganizationMailer < ApplicationMailer
  # Proves that the organization's SMTP settings work.
  def test_email
    @organization = params[:organization]
    @recipient = params[:recipient]
    I18n.with_locale(@recipient.locale.presence || I18n.default_locale) do
      mail to: @recipient.email, subject: t("mailer.organization.test_subject", name: @organization.name)
    end
  end
end
