module Users
  # The user's own API tokens on the account page (specs/api.md "Tokens"):
  # made here, shown once, revoked here or through the API. Never while an
  # administrator impersonates the user.
  class ApiTokensController < ApplicationController
    before_action { authorize!(!impersonator) }

    def create
      token = current_user.api_tokens.new(params.expect(api_token: %i[name read_only expires_in_days]))
      if token.save
        # Shown once on the next page; the session cookie is encrypted and
        # the flash is gone after that page.
        flash[:api_token] = token.plain_token
        redirect_to edit_user_registration_path(anchor: "api-tokens"), notice: t("flash.api_token_created", name: token.name)
      else
        redirect_to edit_user_registration_path(anchor: "api-tokens"), alert: token.errors.full_messages.to_sentence
      end
    end

    def destroy
      token = current_user.api_tokens.find(params[:id])
      token.destroy!
      redirect_to edit_user_registration_path(anchor: "api-tokens"), notice: t("flash.api_token_revoked", name: token.name)
    end
  end
end
