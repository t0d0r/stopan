# Postpones inactive tickets hourly from the web process
# (specs/board.md "Automatic postponing"); only under `rails server`, never
# in the console, rake tasks or tests.
Rails.application.config.after_initialize do
  AutoPostpone.start if defined?(Rails::Server)
end
