# How records look in the JSON API (specs/api.md "Representations").
# Only what the current user may see: requesters never get internal
# notes, internal events, mail headers or other users' emails.
module ApiRepresentation
  private

  def time_json(time)
    time&.utc&.iso8601
  end

  def user_json(user)
    return unless user

    json = { id: user.id, name: user.display_name, role: user.role }
    json[:email] = user.email if current_user.staff? || user == current_user
    json
  end

  def me_json(user)
    user_json(user).merge(username: user.username, language: user.language, deactivated: user.deactivated?,
                          notify_new_tickets: user.notify_new_tickets,
                          organizations: user.organizations.map { |organization| { id: organization.id, name: organization.name } })
  end

  def ticket_json(ticket, full: false)
    json = {
      number: ticket.number, reference: ticket.reference, subject: ticket.subject, status: ticket.status,
      priority: ticket.priority, source: ticket.source, markdown: ticket.markdown?,
      stage: ticket.stage && { id: ticket.stage.id, name: ticket.stage.name },
      organization: { id: ticket.organization.id, name: ticket.organization.name },
      requester: user_json(ticket.requester), assignee: user_json(ticket.assignee),
      created_at: time_json(ticket.created_at), updated_at: time_json(ticket.updated_at),
      done_at: time_json(ticket.done_at), edited_at: time_json(ticket.edited_at), url: ticket_url(ticket)
    }
    return json unless full

    policy = TicketPolicy.new(current_user, ticket)
    json[:description] = ticket.description
    json[:files] = ticket.files.attachments.map { |file| file_json(ticket, file) }
    json[:shared] = ticket.shared?
    json[:share_url] = shared_ticket_url(ticket.share_token) if ticket.shared? && policy.share?
    if current_user.staff?
      json[:mail_headers] = ticket.mail_headers
      json[:next_statuses] = ticket.next_statuses
    end
    events = TicketEvent.visible_to(current_user).where(ticket: ticket)
                        .includes(:actor, comment: [ :author, { files_attachments: :blob } ]).order(:created_at, :id)
    json[:timeline] = events.map { |event| event_json(ticket, event) }
    json
  end

  def event_json(ticket, event)
    {
      id: event.id, action: event.action, from: event.from_value, to: event.to_value, internal: event.internal?,
      actor: user_json(event.actor), created_at: time_json(event.created_at),
      comment: event.comment && comment_json(ticket, event.comment)
    }
  end

  def comment_json(ticket, comment)
    {
      id: comment.id, body: comment.body, internal: comment.internal?, markdown: comment.markdown?,
      source: comment.source, author: user_json(comment.author), created_at: time_json(comment.created_at),
      edited_at: time_json(comment.edited_at),
      files: comment.files.attachments.map { |file| file_json(ticket, file) }
    }
  end

  def file_json(ticket, attachment)
    {
      id: attachment.id, filename: attachment.filename.to_s, content_type: attachment.content_type,
      byte_size: attachment.byte_size, url: api_v1_ticket_attachment_url(ticket, attachment)
    }
  end

  def notification_json(notification)
    {
      id: notification.id, kind: notification.kind, status: notification.status, message: notification.message,
      read: !notification.unread?, actor: user_json(notification.actor), created_at: time_json(notification.created_at),
      ticket: notification.ticket && { number: notification.ticket.number, subject: notification.ticket.subject },
      event_id: notification.event_id
    }
  end

  def organization_json(organization, full: false)
    json = { id: organization.id, name: organization.name, slug: organization.slug }
    return json unless full

    json.merge(
      notes: organization.notes, public_form: organization.public_form, public_intro: organization.public_intro,
      public_allowed_senders: organization.public_allowed_senders, mail_auth: organization.mail_auth,
      smtp_enabled: organization.smtp_enabled, smtp_address: organization.smtp_address, smtp_port: organization.smtp_port,
      smtp_security: organization.smtp_security, smtp_username: organization.smtp_username,
      smtp_password_set: organization.smtp_password.present?, mail_from: organization.mail_from,
      imap_enabled: organization.imap_enabled, imap_address: organization.imap_address, imap_port: organization.imap_port,
      imap_ssl: organization.imap_ssl, imap_username: organization.imap_username,
      imap_password_set: organization.imap_password.present?, imap_folder: organization.imap_folder,
      mailbox_address: organization.mailbox_address, imap_last_checked_at: time_json(organization.imap_last_checked_at),
      imap_last_error: organization.imap_last_error,
      members: organization.memberships.includes(:user).map { |membership| { membership_id: membership.id, user: user_json(membership.user) } }
    )
  end

  def stage_json(stage)
    { id: stage.id, status: stage.status, name: stage.name, color: stage.color, position: stage.position }
  end

  def token_json(token)
    {
      id: token.id, name: token.name, hint: token.token_hint, read_only: token.read_only?,
      created_at: time_json(token.created_at), last_used_at: time_json(token.last_used_at),
      expires_at: time_json(token.expires_at)
    }
  end
end
