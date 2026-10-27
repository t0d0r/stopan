# Checks the organizations' mailboxes every few minutes from the web
# process (specs/organization-mail.md "Fetching"); started by
# config/initializers/mailbox_poller.rb only under `rails server`.
module MailboxPoller
  def self.start(interval:)
    @task ||= Concurrent::TimerTask.new(execution_interval: interval) { check_all }.tap(&:execute)
  end

  def self.check_all
    Rails.application.executor.wrap do
      Organization.where(imap_enabled: true).find_each { |organization| MailboxCheck.new(organization).run }
    end
  rescue StandardError => e
    Rails.logger.error("Mailbox poller: #{e.class}: #{e.message}")
  end
end
