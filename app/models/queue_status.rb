# The job queue as the Status page shows it (specs/status.md "Job
# queue"): counts, failed jobs and recently finished ones, read from Solid
# Queue's own tables. Only production runs Solid Queue; elsewhere there
# is nothing to read.
class QueueStatus
  FAILED_LIMIT = 20
  RECENT_LIMIT = 30
  ERROR_LIMIT = 300
  KEEP_FINISHED = 2.days

  Failed = Struct.new(:id, :name, :at, :error, keyword_init: true)
  Finished = Struct.new(:name, :at, keyword_init: true)

  def self.available?
    ActiveJob::Base.queue_adapter_name.to_s == "solid_queue"
  end

  def self.current
    new if available?
  end

  # Finished jobs older than KEEP_FINISHED go; called by the hourly timer.
  def self.clean
    SolidQueue::Job.clear_finished_in_batches(finished_before: KEEP_FINISHED.ago) if available?
  end

  # What a job was, in plain terms and without its arguments: an email
  # by its mailer and kind, a webhook by its event, else the class.
  def self.name_of(class_name, arguments)
    list = arguments.is_a?(Hash) ? Array(arguments["arguments"]) : []
    case class_name
    when "MailDeliveryJob", "ActionMailer::MailDeliveryJob"
      mailer, kind = list.first(2)
      mailer.is_a?(String) && kind.is_a?(String) ? "#{mailer} #{kind}".first(80) : class_name
    when "WebhookDeliveryJob"
      list[1].is_a?(String) ? "Webhook #{list[1]}".first(80) : class_name
    else class_name.to_s
    end
  end

  def counts
    {
      waiting: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count,
      running: SolidQueue::ClaimedExecution.count,
      failed: SolidQueue::FailedExecution.count,
      finished_day: SolidQueue::Job.where(finished_at: 24.hours.ago..).count
    }
  end

  def failed
    SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(FAILED_LIMIT).map do |execution|
      Failed.new(id: execution.id, name: self.class.name_of(execution.job.class_name, execution.job.arguments),
                 at: execution.created_at, error: "#{execution.exception_class}: #{execution.message}".first(ERROR_LIMIT))
    end
  end

  def recent
    SolidQueue::Job.where.not(finished_at: nil).order(finished_at: :desc).limit(RECENT_LIMIT).map do |job|
      Finished.new(name: self.class.name_of(job.class_name, job.arguments), at: job.finished_at)
    end
  end

  def retry(id)
    SolidQueue::FailedExecution.find(id).retry
  end

  def discard(id)
    SolidQueue::FailedExecution.find(id).discard
  end
end
