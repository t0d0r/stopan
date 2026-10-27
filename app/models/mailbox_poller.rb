# Checks the organizations' mailboxes every few minutes from the web
# process (specs/organization-mail.md "Fetching"); started by
# config/initializers/mailbox_poller.rb only under `rails server`.
module MailboxPoller
  def self.start(interval:)
    @task ||= Concurrent::TimerTask.new(execution_interval: interval) { check_all }.tap(&:execute)
  end

  def self.check_all
    Rails.application.executor.wrap do
      # A Google account that needs reconnecting is skipped (specs/mail-oauth.md).
      Organization.where(imap_enabled: true).find_each do |organization|
        MailboxCheck.new(organization).run if organization.imap_ready?
      end
    end
  rescue StandardError => e
    Rails.logger.error("Mailbox poller: #{e.class}: #{e.message}")
  end
end
