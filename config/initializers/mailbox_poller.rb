# Polls the organizations' IMAP mailboxes from the web process when
# MAILBOX_POLLING=true (specs/organization-mail.md). Only under
# `rails server`, never in the console, rake tasks or tests.
Rails.application.config.after_initialize do
  if ENV["MAILBOX_POLLING"] == "true" && defined?(Rails::Server)
    MailboxPoller.start(interval: Integer(ENV.fetch("MAILBOX_POLL_SECONDS", "120")))
  end
end
