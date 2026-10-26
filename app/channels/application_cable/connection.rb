module ApplicationCable
  # Identifies the signed-in, active user from the Devise session, or
  # nobody: shared ticket pages are public, so visitors connect too. Each
  # stream protects itself (specs/notifications.md, specs/sharing.md).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      user = env["warden"]&.user(:user)
      self.current_user = user if user&.active_for_authentication?
    end
  end
end
