module Admin
  # Messages from administrators, shown in the recipients' notifications
  # (specs/notifications.md "Messages from administrators").
  class MessagesController < BaseController
    def new
      recipients = if params[:user_id] then "user:#{params[:user_id].to_i}"
      elsif params[:organization_id] then "organization:#{params[:organization_id].to_i}"
      end
      @message = AdminMessage.new(recipients: recipients, sender: current_user)
      @return_to = safe_return_path
    end

    def create
      @message = AdminMessage.new(params.expect(admin_message: %i[recipients text]).merge(sender: current_user))
      @return_to = safe_return_path
      if @message.valid?
        count = @message.deliver
        redirect_to @return_to, notice: t("flash.message_sent", count: count)
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    # Back to the admin page the form came from; only admin paths.
    def safe_return_path
      path = params[:return_to].to_s
      path.start_with?("/admin") && !path.start_with?("//") ? path : admin_users_path
    end
  end
end
