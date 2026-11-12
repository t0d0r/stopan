module Admin
  # What the service desk did in the background, for super administrators
  # (specs/status.md): mail taken in, the job queue, failing webhooks.
  class StatusController < BaseController
    before_action :require_super_admin
    before_action :require_queue, only: %i[retry_job discard_job]

    def show
      @setting = AppSetting.current
      @mailboxes = Organization.where(imap_enabled: true).order(:name).to_a
      @mail_log = MailboxEvent.newest_first.includes(:organization, :ticket).limit(50).to_a
      @queue = QueueStatus.current
      @webhooks = Webhook.problems.includes(:organization).to_a
    end

    def retry_job
      @queue.retry(params[:id])
      redirect_to admin_status_path(anchor: "jobs"), notice: t("flash.job_retried")
    end

    def discard_job
      @queue.discard(params[:id])
      redirect_to admin_status_path(anchor: "jobs"), notice: t("flash.job_discarded")
    end

    private

    def require_queue
      @queue = QueueStatus.current
      redirect_to admin_status_path, alert: t("flash.queue_unavailable") unless @queue
    end
  end
end
