module ApplicationHelper
  # Cookie values set by the sun/moon switch and the text size buttons.
  def theme_preference
    cookies[:theme].presence_in(PreferencesController::THEMES)
  end

  def scale_preference
    cookies[:scale].presence_in(PreferencesController::SCALES) || "normal"
  end

  def width_preference
    cookies[:width].presence_in(PreferencesController::WIDTHS) || "normal"
  end

  # Each language named in itself, for the language switch (ui.md "Language").
  LANGUAGE_NAMES = { "en" => "English", "bg" => "Български", "de" => "Deutsch" }.freeze

  # The header language switch is for visitors and shared pages; signed-in
  # users choose on the account page (ui.md "Language").
  def language_switch?
    !user_signed_in? || controller_name == "shared_tickets"
  end

  # The languages the header switch offers: all but the one shown now.
  def other_languages
    LANGUAGE_NAMES.keys - [ I18n.locale.to_s ]
  end

  # data-* attributes for a form that asks before submitting; the confirm
  # dialog (partials/_confirm_dialog) shows the title, message and button.
  def confirm_data(title:, body:, button:)
    { confirm: body, confirm_title: title, confirm_button: button }
  end

  # Devise reports errors as :alert.
  def flash_kind(type)
    %w[alert error].include?(type.to_s) ? "alert" : "notice"
  end

  # "5 minutes ago" in a <time> element with the exact time as tooltip.
  def time_ago(time)
    return "-" unless time

    tag.time(t("ui.ago", time: time_ago_in_words(time)), datetime: time.iso8601, title: l(time, format: :long))
  end

  # Which menu bar section the page belongs to.
  def current_section
    if controller_path.start_with?("admin/") then :admin
    elsif controller_name == "tickets" && action_name.in?(%w[new create]) then :new_ticket
    elsif controller_name.in?(%w[tickets comments boards]) then :tickets
    end
  end

  # A menu bar section link with its paper colour square.
  def nav_link(label, path, dot:, current:)
    link_to path, class: "nav-link", aria: { current: ("page" if current) } do
      tag.span(class: "nav-link__dot sticky--#{dot}", "aria-hidden": "true") + label
    end
  end

  # Admin pages refresh live for administrators (specs/admin.md).
  def live_admin_page?
    user_signed_in? && current_user.admin? && current_section == :admin
  end

  # Hidden fields of the menu bar search (queues.md): on a ticket list it
  # searches within the list's view, filters and sort; elsewhere all tickets.
  def search_scope_params
    @filter ? @filter.params_with(q: nil, page: nil) : { view: "all" }
  end

  # Unread count and newest notifications for the menu bar panel.
  def notification_panel
    scope = Notification.visible_to(current_user)
    { unread: scope.unread.count, latest: scope.newest_first.includes(:actor, :ticket).limit(8).to_a }
  end

  # "Maria Ivanova replied" (specs/notifications.md "Notification panel").
  def notification_sentence(notification)
    actor = notification.actor&.display_name || t("ui.timeline.system")
    status = notification.status && t("ui.statuses.#{notification.status}")
    if notification.kind == "status_changed" || (notification.kind == "replied" && status)
      key = notification.kind == "replied" ? "replied_status" : "status_changed"
      t("ui.notifications.kinds.#{key}", actor: actor, status: status)
    else
      t("ui.notifications.kinds.#{notification.kind}", actor: actor)
    end
  end

  def role_label(user)
    t("ui.roles.#{user.role}")
  end

  # The menu bar shows the role as an icon, named for screen readers and in
  # its tooltip (ui.md "Menu bar").
  ROLE_ICONS = { "requester" => :user, "agent" => :headset, "admin" => :shield }.freeze

  def role_icon(user)
    tag.span(icon(ROLE_ICONS.fetch(user.role), label: role_label(user), size: 13),
             class: "menubar__role menubar__role--#{user.role}", title: role_label(user))
  end

  # Errors of a form, listed at the top (role=alert, ui.md).
  def form_errors(record)
    return if record.errors.empty?

    tag.div(class: "form-errors", role: "alert") do
      tag.p(t("ui.form_errors", count: record.errors.count), class: "form-errors__title") +
        tag.ul { safe_join(record.errors.full_messages.map { |message| tag.li(message) }) }
    end
  end

  def invalid?(record, attribute)
    record.errors[attribute].any? || record.errors[attribute.to_s.delete_suffix("_id")].any?
  end
end
