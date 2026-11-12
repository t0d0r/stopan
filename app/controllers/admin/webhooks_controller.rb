module Admin
  # Webhooks of an organization, for super administrators only: they
  # send ticket text to another system (specs/webhooks.md).
  class WebhooksController < BaseController
    before_action :require_super_admin
    before_action :set_webhook, only: %i[update destroy ping]

    def create
      organization = Organization.find(params[:organization_id])
      webhook = organization.webhooks.new(url: params.dig(:webhook, :url), event_names: params.dig(:webhook, :events))
      if webhook.save
        # Shown once, on the next page only.
        flash[:webhook_secret] = webhook.secret
        redirect_to back(organization), notice: t("flash.webhook_created")
      else
        redirect_to back(organization), alert: webhook.errors.full_messages.to_sentence
      end
    end

    # Switch on or off; switching on starts the failure count again.
    def update
      active = params.dig(:webhook, :active).to_s == "1"
      @webhook.update!(active: active, failures: active ? 0 : @webhook.failures)
      redirect_to back(@webhook.organization), notice: t(active ? "flash.webhook_on" : "flash.webhook_off")
    end

    def destroy
      @webhook.destroy!
      redirect_to back(@webhook.organization), notice: t("flash.webhook_deleted")
    end

    def ping
      return redirect_to(back(@webhook.organization), alert: t("flash.webhook_is_off")) unless @webhook.active?

      @webhook.ping!
      redirect_to back(@webhook.organization), notice: t("flash.webhook_pinged")
    end

    private

    def set_webhook
      @webhook = Webhook.find(params[:id])
    end

    def back(organization)
      admin_organization_path(organization, anchor: "webhooks")
    end
  end
end
