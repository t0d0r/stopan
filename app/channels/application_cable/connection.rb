module ApplicationCable
  # WebSocket connections are for signed-in, active users only; they carry
  # the notification panel's refresh signal (specs/notifications.md).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      user = env["warden"]&.user(:user)
      reject_unauthorized_connection unless user&.active_for_authentication?
      self.current_user = user
    end
  end
end
