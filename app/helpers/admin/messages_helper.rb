module Admin
  module MessagesHelper
    # Grouped recipient choices, each with how many active users it reaches
    # (data-count, shown by application.js), never counting the sender.
    def message_recipient_options(selected)
      count = ->(value) { AdminMessage.new(recipients: value, sender: current_user).recipient_users.count }
      option = ->(label, value, number = count.call(value)) { [ label, value, { data: { count: number } } ] }
      groups = {}
      # Organization administrators: their organizations and members only (specs/org-admins.md).
      if current_user.admin?
        groups[t("ui.admin.messages.groups.everyone")] = [ option.call(t("ui.admin.messages.all"), "all") ]
        groups[t("ui.admin.messages.groups.roles")] = User::ROLES.map { |role| option.call(t("ui.admin.messages.role", role: t("ui.roles.#{role}")), "role:#{role}") }
      end
      groups[t("ui.admin.messages.groups.organizations")] = admin_scope.organizations.ordered.map { |org| option.call(t("ui.admin.messages.members_of", name: org.name), "organization:#{org.id}") }
      groups[t("ui.admin.messages.groups.users")] = admin_scope.users.active.where.not(id: current_user.id).ordered.map { |user| option.call("#{user.display_name} (#{user.email})", "user:#{user.id}", 1) }
      grouped_options_for_select(groups, selected)
    end
  end
end
