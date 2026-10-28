# Mail about a user's own account (specs/public-form.md).
class AccountMailer < ApplicationMailer
  # A one-time sign-in link, asked for on the sign-in page.
  def magic_link
    @resource = params[:user]
    @url = magic_link_url(@resource.generate_token_for(:magic_sign_in))
    I18n.with_locale(@resource.mail_locale(@resource.only_organization)) do
      mail to: @resource.email, subject: t("mailer.magic_link.subject")
    end
  end
end
