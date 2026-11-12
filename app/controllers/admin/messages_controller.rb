module Admin
  # Messages from administrators, shown in the recipients' notifications
  # (specs/notifications.md "Messages from administrators").
  class MessagesController < BaseController
    def new
      recipients = if params[:user_id] then "user:#{params[:user_id].to_i}"
      elsif params[:organization_id] then "organization:#{params[:organization_id].to_i}"
      end
      @message = AdminMessage.new(recipients: recipients, sender: current_user)
      session[:message_return] = admin_path(referer_path) || admin_path(params[:return_to])
      @return_to = return_path
    end

    def create
      @message = AdminMessage.new(params.expect(admin_message: %i[recipients text]).merge(sender: current_user))
      @return_to = return_path
      if @message.valid?
        count = @message.deliver
        session.delete(:message_return)
        redirect_to @return_to, notice: t("flash.message_sent", count: count)
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    # Back to the admin page the form was opened from. `new` takes that
    # page from the Referer header and keeps it in the session, so no
    # address travels in a form field: the web application firewall in
    # front of the app refuses long addresses there (specs/admin.md
    # "Message form"). `return_to` is still read, for clients that send it.
    def return_path
      admin_path(session[:message_return]) || admin_path(params[:return_to]) || admin_users_path
    end

    # Only admin paths, and not the message form itself.
    def admin_path(path)
      path = path.to_s
      path if path.match?(%r{\A/admin(/|\?|\z)}) && !path.start_with?("/admin/messages")
    end
  end
end
