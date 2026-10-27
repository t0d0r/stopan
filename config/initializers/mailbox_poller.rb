# Starts the mailbox poller under `rails server`, never in the console,
# rake tasks or tests; whether it fetches is set on /admin/settings
# (specs/organization-mail.md "Fetching"). MAILBOX_POLLING=false keeps it
# from starting at all.
Rails.application.config.after_initialize do
  MailboxPoller.start if ENV["MAILBOX_POLLING"] != "false" && defined?(Rails::Server)
end
