require "test_helper"

# Queued emails are retried (specs/notifications.md "Delivery").
class MailDeliveryJobTest < ActiveJob::TestCase
  # A mail server that always refuses.
  class Refusing
    cattr_accessor :attempts, default: 0

    def initialize(*) = nil

    def deliver!(_mail)
      self.class.attempts += 1
      raise Net::SMTPServerBusy, "busy"
    end
  end

  setup do
    Refusing.attempts = 0
    ActionMailer::Base.add_delivery_method :refusing, Refusing
  end

  teardown { AccountMailer.delivery_method = :test }

  test "emails are queued as the retrying job" do
    assert_equal MailDeliveryJob, ActionMailer::Base.delivery_job
    assert_enqueued_with(job: MailDeliveryJob) { AccountMailer.with(user: users(:anna)).magic_link.deliver_later }
  end

  test "a refused email is tried 5 times, then the error is left to the queue" do
    AccountMailer.delivery_method = :refusing
    AccountMailer.with(user: users(:anna)).magic_link.deliver_later
    # Each failed attempt queues the next; the last one raises.
    assert_raises(Net::SMTPServerBusy) { 5.times { perform_enqueued_jobs } }
    assert_no_enqueued_jobs
    assert_equal 5, Refusing.attempts
  end

  test "production keeps the jobs in a second database, run inside Puma" do
    production = ActiveRecord::Base.configurations.configs_for(env_name: "production")
    assert_equal %w[primary queue], production.map(&:name)
    assert_equal "storage/production_queue.sqlite3", production.last.database
    assert_includes Rails.root.join("db/queue_schema.rb").read, "solid_queue_jobs"
    puma = Rails.root.join("config/puma.rb").read
    assert_match(/^  plugin :solid_queue$/, puma)
    assert_match(/^  solid_queue_mode :async$/, puma, "forked workers could not refresh pages over the async cable")
  end
end
