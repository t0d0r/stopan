module Api
  module V1
    # Webhooks of an organization, for administrators (specs/webhooks.md).
    # The secret is in the answer to create only.
    class WebhooksController < BaseController
      before_action :require_admin!
      before_action :set_webhook, only: %i[update destroy ping]

      def index
        organization = Organization.find(params[:organization_id])
        render json: { webhooks: organization.webhooks.ordered.map { |webhook| webhook_json(webhook) } }
      end

      def create
        organization = Organization.find(params[:organization_id])
        attributes = params.expect(webhook: [ :url, events: [] ])
        webhook = organization.webhooks.new(url: attributes[:url], event_names: attributes[:events])
        return render_invalid(webhook) unless webhook.save

        render json: { webhook: webhook_json(webhook).merge(secret: webhook.secret) }, status: :created
      end

      def update
        active = flag(params.expect(webhook: [ :active ])[:active])
        @webhook.update!(active: active, failures: active ? 0 : @webhook.failures)
        render json: { webhook: webhook_json(@webhook) }
      end

      def destroy
        @webhook.destroy!
        head :no_content
      end

      def ping
        return render_error(:invalid, :unprocessable_content, message: I18n.t("flash.webhook_is_off")) unless @webhook.active?

        @webhook.ping!
        render json: { queued: true }
      end

      private

      def set_webhook
        @webhook = Webhook.find(params[:id])
      end

      def webhook_json(webhook)
        { id: webhook.id, organization: organization_json(webhook.organization), url: webhook.url, events: webhook.event_names,
          active: webhook.active?, failures: webhook.failures, last_status: webhook.last_status, last_error: webhook.last_error,
          last_sent_at: time_json(webhook.last_sent_at), created_at: time_json(webhook.created_at) }
      end
    end
  end
end
