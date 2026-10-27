module Admin
  module MessagesHelper
    # Grouped recipient choices, each with how many active users it reaches
    # (data-count, shown by application.js), never counting the sender.
    def message_recipient_options(selected)
      count = ->(value) { AdminMessage.new(recipients: value, sender: current_user).recipient_users.count }
      option = ->(label, value, number = count.call(value)) { [ label, value, { data: { count: number } } ] }
      groups = {
        t("ui.admin.messages.groups.everyone") => [ option.call(t("ui.admin.messages.all"), "all") ],
        t("ui.admin.messages.groups.roles") => User::ROLES.map { |role| option.call(t("ui.admin.messages.role", role: t("ui.roles.#{role}")), "role:#{role}") },
        t("ui.admin.messages.groups.organizations") => Organization.ordered.map { |org| option.call(t("ui.admin.messages.members_of", name: org.name), "organization:#{org.id}") },
        t("ui.admin.messages.groups.users") => User.active.where.not(id: current_user.id).ordered.map { |user| option.call("#{user.display_name} (#{user.email})", "user:#{user.id}", 1) }
      }
      grouped_options_for_select(groups, selected)
    end
  end
end
