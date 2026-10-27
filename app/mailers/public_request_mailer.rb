# Confirmation of a request sent through a public page, with a one-time
# sign-in link that opens the ticket (specs/public-form.md).
class PublicRequestMailer < ApplicationMailer
  helper :tickets, :markdown

  def received
    @ticket = params[:ticket]
    @resource = @ticket.requester
    @url = magic_link_url(@resource.generate_token_for(:magic_sign_in), ticket: @ticket.number)
    I18n.with_locale(@resource.locale.presence || I18n.default_locale) do
      headers["References"] = "<ticket-#{@ticket.number}@#{default_url_options[:host]}>"
      mail to: @resource.email,
           subject: t("mailer.public_request.subject", number: @ticket.number, subject: @ticket.subject)
    end
  end
end
