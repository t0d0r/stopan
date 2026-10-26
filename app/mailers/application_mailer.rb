class ApplicationMailer < ActionMailer::Base
  # The same sender as Devise's emails (specs/notifications.md).
  default from: -> { Devise.mailer_sender }
  layout "mailer"
end
