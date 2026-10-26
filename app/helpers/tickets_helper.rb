module TicketsHelper
  # Paper colour per status and priority; always shown with its text (ui.md).
  STATUS_COLORS = { "new" => "yellow", "open" => "pink", "pending" => "blue", "resolved" => "green",
                    "closed" => "gray" }.freeze
  PRIORITY_COLORS = { "low" => "gray", "normal" => "blue", "high" => "purple", "urgent" => "pink" }.freeze
  # Paper colour per list view (queues.md); pending and solved match their statuses.
  VIEW_COLORS = { "unsolved" => "yellow", "mine" => "purple", "unassigned" => "pink", "pending" => "blue",
                  "solved" => "green", "all" => "gray", "open" => "yellow" }.freeze
  AVATAR_COLORS = %w[yellow blue green pink purple gray].freeze

  def status_name(status)
    t("ui.statuses.#{status}")
  end

  def priority_name(priority)
    t("ui.priorities.#{priority}")
  end

  def status_pill(status)
    tag.span(status_name(status), class: "pill pill--status sticky--#{STATUS_COLORS.fetch(status, 'gray')}")
  end

  def priority_pill(priority)
    tag.span(priority_name(priority), class: "pill pill--priority pill--#{priority} sticky--#{PRIORITY_COLORS.fetch(priority, 'gray')}")
  end

  # Plain text with line breaks; HTML in the text is escaped.
  def ticket_text(text)
    simple_format(h(text), class: "ticket-text__p")
  end

  def user_name(user)
    user&.display_name || t("ui.timeline.system")
  end

  # One sentence for a property event, e.g. "Maria changed status from Open
  # to Pending".
  def event_sentence(event)
    actor = user_name(event.actor)
    case event.action
    when "created" then t("ui.timeline.created", actor: actor)
    when "status_changed"
      t("ui.timeline.status_changed", actor: actor, from: status_name(event.from_value), to: status_name(event.to_value))
    when "priority_changed"
      t("ui.timeline.priority_changed", actor: actor, from: priority_name(event.from_value),
                                         to: priority_name(event.to_value))
    when "assignee_changed"
      to = event.to_value.present? ? assignee_name(event.to_value) : nil
      to ? t("ui.timeline.assigned", actor: actor, to: to) : t("ui.timeline.unassigned", actor: actor)
    when "shared"
      event.to_value == "password" ? t("ui.timeline.shared_password", actor: actor) : t("ui.timeline.shared", actor: actor)
    when "unshared" then t("ui.timeline.unshared", actor: actor)
    end
  end

  def event_icon(event)
    { "created" => :spark, "status_changed" => :status, "priority_changed" => :flag,
      "assignee_changed" => :user, "shared" => :link, "unshared" => :link }.fetch(event.action, :spark)
  end

  def assignee_name(user_id)
    @assignee_names ||= {}
    @assignee_names[user_id] ||= User.find_by(id: user_id)&.display_name || t("ui.timeline.removed_user")
  end

  # On a shared page (share_token) files go through the share link.
  def attachment_link(ticket, attachment, share_token: nil)
    path = share_token ? shared_ticket_file_path(share_token, attachment) : ticket_attachment_path(ticket, attachment)
    link_to path, class: "file-link", data: { turbo: false } do
      icon(:clip) + tag.span(attachment.filename.to_s, class: "file-link__name") +
        tag.span(number_to_human_size(attachment.byte_size), class: "file-link__size")
    end
  end

  # Staff can pick the current status or an allowed transition.
  def status_options(ticket)
    current = ticket.status_was || ticket.status
    ([ current ] + Ticket::TRANSITIONS.fetch(current, [])).map { |status| [ status_name(status), status ] }
  end

  def priority_options
    Ticket::PRIORITIES.map { |priority| [ priority_name(priority), priority ] }
  end

  def staff_options(staff)
    staff.map { |user| [ user.display_name, user.id ] }
  end

  def queue_view_label(view)
    t("ui.queue.views.#{view}")
  end

  def view_color(view)
    VIEW_COLORS.fetch(view, "gray")
  end

  # Initials on a paper colour picked from the user id, so a person keeps
  # their colour. Decorative: the name is always shown next to it.
  def user_avatar(user)
    initials = user.display_name.split.first(2).map { |word| word[0] }.join.upcase
    tag.span(initials, class: "avatar sticky--#{AVATAR_COLORS[user.id % AVATAR_COLORS.size]}", "aria-hidden": "true")
  end
end
