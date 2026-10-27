# Checks the organizations' mailboxes from the web process when an
# administrator turns automatic fetching on (specs/organization-mail.md
# "Fetching"); started by config/initializers/mailbox_poller.rb only under
# `rails server`. It wakes every TICK seconds and reads the setting, so a
# change applies without a restart.
module MailboxPoller
  TICK = 30

  def self.start
    @task ||= Concurrent::TimerTask.new(execution_interval: TICK) { tick }.tap(&:execute)
  end

  # Checks when fetching is on and its interval has passed (half a tick of
  # slack, so timer jitter does not skip a round). True when it checked.
  def self.tick(now = Time.current)
    Rails.application.executor.wrap do
      setting = AppSetting.current
      return false unless setting.mailbox_polling?
      return false if @last_check && now - @last_check < setting.mailbox_poll_seconds - TICK / 2

      @last_check = now
      check_all
      true
    end
  rescue StandardError => e
    Rails.logger.error("Mailbox poller: #{e.class}: #{e.message}")
    false
  end

  def self.check_all
    # A Google account that needs reconnecting is skipped (specs/mail-oauth.md).
    Organization.where(imap_enabled: true).find_each do |organization|
      MailboxCheck.new(organization).run if organization.imap_ready?
    end
  end

  def self.reset
    @last_check = nil
  end
end
