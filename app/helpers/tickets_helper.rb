module TicketsHelper
  include MarkdownHelper

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

  # The current text of a request or comment, formatted when it is
  # Markdown (specs/markdown.md); used by pages and emails.
  def formatted_text(record)
    text = record.is_a?(Ticket) ? record.description : record.body
    record.markdown? ? render_markdown(text) : ticket_text(text)
  end

  # The message text as shown on a page; the copy box reads it.
  def message_text(record)
    tag.div(formatted_text(record), class: [ "ticket-text", ("markdown-body" if record.markdown?) ],
                                    data: { message_text: true })
  end

  # "M" box in a message's title strip that switches Markdown on or off.
  def markdown_box(path, on:)
    label = on ? t("ui.markdown.turn_off") : t("ui.markdown.turn_on")
    button_to path, method: :patch, params: { markdown: on ? "0" : "1" }, form_class: "markdown-box__form",
                    class: "sticky__box sticky__box--icon markdown-box", title: label,
                    aria: { label: label, pressed: on } do
      icon(:markdown, size: 10)
    end
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
  # "edited by Maria 5 minutes ago" on an edited request or comment
  # (specs/timeline.md "Editing").
  def edited_note(record)
    return unless record.edited?

    tag.span(class: "edited-tag") do
      safe_join([ t("ui.edit.edited_by", name: record.edited_by&.display_name), time_ago(record.edited_at) ], " ")
    end
  end

  # Copies the text of the message it sits in ([data-message-text]); shown
  # by application.js (specs/ui.md "Copy box").
  def copy_box
    tag.button(type: "button", class: "sticky__box sticky__box--icon copy-box", hidden: true,
               title: t("ui.copy.label"), aria: { label: t("ui.copy.label") },
               data: { copy_message: true, label: t("ui.copy.label"), copied: t("ui.copy.copied") }) do
      icon(:copy, size: 10) + tag.span(icon(:check, size: 10), class: "copy-box__done")
    end
  end

  # Opens the edit form in place of the text (a Turbo frame).
  def edit_link(path, frame:)
    link_to path, class: "edit-link", data: { turbo_frame: frame } do
      icon(:pencil, size: 12) + tag.span(t("ui.edit.edit"))
    end
  end

  # Live count of open shared pages of the ticket's link (specs/sharing.md
  # "Who is viewing now"); application.js swaps the text on each signal.
  # scope: :page (the shared page, counting the reader) or :panel.
  def share_viewers_tag(count, scope:)
    texts = %i[zero one other].filter_map do |key|
      [ key, t("ui.share.viewers.#{scope}.#{key}") ] if I18n.exists?("ui.share.viewers.#{scope}.#{key}")
    end.to_h
    tag.p(class: "share-viewers", data: { count: count }) do
      tag.span(class: "share-viewers__dot", aria: { hidden: true }) + icon(:eye, size: 13) +
        tag.span(t("ui.share.viewers.#{scope}", count: count), data: { share_viewers: true, **texts }, aria: { live: "polite" })
    end
  end

  # A download link that opens the preview dialog for previewable kinds
  # (specs/attachments.md "Preview"); modified clicks still download.
  def attachment_link(ticket, attachment, share_token: nil)
    path = share_token ? shared_ticket_file_path(share_token, attachment) : ticket_attachment_path(ticket, attachment)
    kind = Attachable.preview_kind(attachment.blob)
    preview = if kind
      share_token ? shared_ticket_file_preview_path(share_token, attachment) : preview_ticket_attachment_path(ticket, attachment)
    end
    data = { turbo: false, preview_item: true, preview_kind: kind || "none", preview_url: preview,
             filename: attachment.filename.to_s, details: number_to_human_size(attachment.byte_size) }
    link_to path, class: "file-link", data: data do
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
