# The OpenAPI 3.1 description of the JSON API (specs/api.md "OpenAPI"),
# built here as a hash and served as GET /api/v1/openapi.json. Every
# route of the API has an operation; test/models/openapi_document_test.rb
# compares the two, so a new route cannot be left out.
module OpenapiDocument
  PREFIX = "/api/v1".freeze

  ERRORS = {
    "400" => [ "BadRequest", "A required top-level key is missing (`bad_request`)." ],
    "401" => [ "Unauthorized", "No token, or an unknown, expired or revoked one (`unauthorized`)." ],
    "403" => [ "Forbidden", "Not allowed for this user (`forbidden`), or a write with a read-only token (`read_only`)." ],
    "404" => [ "NotFound", "No such record among those the user may see (`not_found`)." ],
    "422" => [ "Invalid", "The input was refused (`invalid`); `details` lists the fields." ],
    "429" => [ "RateLimited", "More than 300 requests a minute with this token (`rate_limited`)." ]
  }.freeze

  module_function

  def to_h
    @to_h ||= build.deep_stringify_keys.freeze
  end

  def to_json(*)
    @to_json ||= JSON.pretty_generate(to_h)
  end

  def build
    {
      openapi: "3.1.0",
      info: {
        title: "Stopan API",
        version: "v1",
        description: "The JSON API of the Stopan service desk. A personal token acts as its user, with the " \
                     "same rights as on the pages. Tokens are made on the account page; a read-only token " \
                     "may only use GET. Dates are ISO 8601 in UTC; tickets are addressed by their number."
      },
      servers: [ { url: "/", description: "This Stopan" } ],
      security: [ { bearer: [] } ],
      tags: TAGS.map { |name, description| { name: name, description: description } },
      paths: paths,
      components: {
        securitySchemes: { bearer: { type: "http", scheme: "bearer", description: "Authorization: Bearer stopan_..." } },
        parameters: PARAMETERS,
        responses: error_responses,
        schemas: SCHEMAS
      }
    }
  end

  def paths
    OPERATIONS.each_with_object({}) do |(verb, path, tag, summary, options), result|
      (result["#{PREFIX}#{path}"] ||= {})[verb] = operation(verb, path, tag, summary, options || {})
    end
  end

  def operation(verb, path, tag, summary, options)
    parameters = path.scan(/\{(\w+)\}/).flatten.map { |name| { "$ref": "#/components/parameters/#{name}" } }
    parameters += (options[:query] || {}).map { |name, description| query_parameter(name, description) }
    body = options[:body]
    {
      operationId: operation_id(verb, path),
      tags: [ tag ],
      summary: summary,
      parameters: parameters.presence,
      requestBody: body && request_body(body, options[:multipart]),
      responses: responses(verb, path, options)
    }.compact
  end

  # "get /tickets/{number}/comments" -> "getTicketsNumberComments"
  def operation_id(verb, path)
    verb + path.scan(/\w+/).map { |part| part.camelize }.join
  end

  def query_parameter(name, description)
    { name: name.to_s, in: "query", required: false, description: description, schema: { type: "string" } }
  end

  def request_body(properties, multipart)
    schema = { type: "object", properties: properties }
    content = { "application/json" => { schema: schema } }
    content["multipart/form-data"] = { schema: schema } if multipart
    { required: true, content: content }
  end

  def responses(verb, path, options)
    status = (options[:status] || 200).to_s
    success = if status == "204"
      { description: "Done, no content." }
    elsif options[:file]
      { description: "The file, as a download.", content: { "application/octet-stream" => { schema: { type: "string", format: "binary" } } } }
    else
      { description: "OK", content: { "application/json" => { schema: options[:returns] || { type: "object" } } } }
    end
    codes = %w[401 403 429]
    codes << "404" if path.include?("{")
    codes += %w[400 422] if options[:body]
    { status => success }.merge(codes.sort.index_with { |code| { "$ref": "#/components/responses/#{ERRORS.fetch(code).first}" } })
  end

  def error_responses
    ERRORS.values.to_h do |name, description|
      [ name, { description: description, content: { "application/json" => { schema: { "$ref": "#/components/schemas/Error" } } } } ]
    end
  end

  def self.ref(name) = { "$ref": "#/components/schemas/#{name}" }
  def self.list(name) = { type: "array", items: ref(name) }
  def self.wrap(key, schema) = { type: "object", properties: { key => schema } }
  def self.str(description = nil, **more) = { type: "string", description: description, **more }.compact
  def self.int(description = nil) = { type: "integer", description: description }.compact
  def self.bool(description = nil) = { type: "boolean", description: description }.compact
  def self.time(description = nil) = { type: %w[string null], format: "date-time", description: description }.compact
  def self.nullable(name) = { anyOf: [ ref(name), { type: "null" } ] }

  TAGS = {
    "Me" => "The user of the token and their tokens.",
    "Tickets" => "Tickets, their description, replies, files, followers, sharing and translations.",
    "Notifications" => "The user's notifications.",
    "Staff" => "For agents and administrators: reports, board stages, people.",
    "Admin" => "For administrators only: users, organizations, settings, messages, deleted tickets."
  }.freeze

  PARAMETERS = {
    number: { name: "number", in: "path", required: true, description: "The ticket's number.", schema: { type: "string" } },
    id: { name: "id", in: "path", required: true, description: "The record's id.", schema: { type: "integer" } },
    organization_id: { name: "organization_id", in: "path", required: true, description: "The organization's id.",
                       schema: { type: "integer" } }
  }.freeze

  STATUS = str("new, open, pending, postponed or done", enum: Ticket::STATUSES)
  PRIORITY = str("low, normal, high or urgent", enum: Ticket::PRIORITIES)
  NAMED = { type: "object", properties: { id: int, name: str } }.freeze

  TICKET_FIELDS = {
    number: int, reference: str("As shown to people, with its prefix."), subject: str, status: STATUS, priority: PRIORITY,
    source: str(nil, enum: Ticket::SOURCES), markdown: bool,
    stage: { anyOf: [ NAMED, { type: "null" } ] }, organization: NAMED,
    requester: ref("User"), assignee: nullable("User"),
    created_at: time, updated_at: time("The last activity."), done_at: time, edited_at: time,
    url: str("The ticket's page.")
  }.freeze

  SCHEMAS = {
    Error: wrap(:error, { type: "object", required: %w[code message], properties: {
      code: str(nil, enum: %w[unauthorized forbidden read_only not_found bad_request invalid rate_limited]),
      message: str("In the user's language."),
      details: { type: "object", description: "Field name to messages, for `invalid`.",
                 additionalProperties: { type: "array", items: { type: "string" } } }
    } }),
    User: { type: "object", description: "A person, in short. `email` only for staff and for the user themself.",
            properties: { id: int, name: str, role: str(nil, enum: User::ROLES), email: str } },
    Me: { allOf: [ ref("User"), { type: "object", properties: {
      username: { type: %w[string null] }, language: { type: %w[string null] }, deactivated: bool, notify_new_tickets: bool,
      organizations: { type: "array", items: NAMED }
    } } ] },
    AdminUser: { allOf: [ ref("User"), { type: "object", properties: {
      username: { type: %w[string null] }, deactivated: bool, language: { type: %w[string null] }, created_at: time,
      last_sign_in_at: time, organizations: list("Organization")
    } } ] },
    Token: { type: "object", description: "A token without its secret.", properties: {
      id: int, name: str, hint: str("The last 4 characters."), read_only: bool, created_at: time, last_used_at: time,
      expires_at: time
    } },
    File: { type: "object", properties: { id: int, filename: str, content_type: str, byte_size: int,
                                          url: str("The API download address.") } },
    Ticket: { type: "object", properties: TICKET_FIELDS },
    TicketDetails: { allOf: [ ref("Ticket"), { type: "object", properties: {
      description: str, files: list("File"), shared: bool,
      share_url: str("When shared and the user may share."), share_expires_at: time, share_views: int,
      share_last_viewed_at: time,
      mail_headers: { type: %w[object null], description: "Staff only: headers of the mail the ticket came from." },
      next_statuses: { type: "array", items: STATUS, description: "Staff only." },
      followers: list("Follower"),
      cc_suggestions: { type: "array", items: str, description: "Staff who may update it: addresses from the mail." },
      cc_candidates: { type: "array", items: NAMED, description: "The requester: colleagues who can be put in Cc." },
      timeline: list("Event")
    } } ] },
    Follower: { type: "object", properties: { id: int, kind: str(nil, enum: %w[staff cc]), user: ref("User"),
                                              added_by: nullable("User"), created_at: time } },
    Comment: { type: "object", properties: {
      id: int, body: str, internal: bool, markdown: bool, source: str(nil, enum: Comment::SOURCES), author: ref("User"),
      created_at: time, edited_at: time, files: list("File"),
      mail_headers: { type: "object", description: "Staff only, on a reply that came in by mail." }
    } },
    Event: { type: "object", description: "One entry of the ticket's history.", properties: {
      id: int, action: str, from: { type: %w[string null] }, to: { type: %w[string null] }, internal: bool,
      actor: nullable("User"), created_at: time, comment: nullable("Comment")
    } },
    Revision: { type: "object", properties: { id: int, record: str("`description` or `comment-<id>`."),
                                              subject: { type: %w[string null] }, body: str, editor: nullable("User"),
                                              created_at: time } },
    Notification: { type: "object", properties: {
      id: int, kind: str, status: { type: %w[string null] }, message: { type: %w[string null] }, read: bool,
      actor: nullable("User"), created_at: time,
      ticket: { type: %w[object null], properties: { number: int, subject: str } }, event_id: { type: %w[integer null] }
    } },
    Stage: { type: "object", properties: { id: int, status: STATUS, name: str, color: str, position: int } },
    Organization: { type: "object", properties: { id: int, name: str, slug: str } },
    OrganizationDetails: { allOf: [ ref("Organization"), { type: "object",
      description: "With its mail settings. Passwords are never returned, only whether one is set.",
      properties: {
        notes: { type: %w[string null] }, public_form: bool, public_intro: { type: %w[string null] },
        public_allowed_senders: { type: %w[string null] }, mail_auth: str,
        smtp_enabled: bool, smtp_address: { type: %w[string null] }, smtp_port: { type: %w[integer null] },
        smtp_security: { type: %w[string null] }, smtp_username: { type: %w[string null] }, smtp_password_set: bool,
        mail_from: { type: %w[string null] },
        imap_enabled: bool, imap_address: { type: %w[string null] }, imap_port: { type: %w[integer null] }, imap_ssl: bool,
        imap_username: { type: %w[string null] }, imap_password_set: bool, imap_folder: { type: %w[string null] },
        mailbox_address: { type: %w[string null] }, imap_last_checked_at: time, imap_last_error: { type: %w[string null] },
        members: { type: "array", items: { type: "object", properties: { membership_id: int, admin: bool, user: ref("User") } } }
      } } ] },
    Membership: { type: "object", properties: { id: int, admin: bool("Organization administrator."),
                                                organization: ref("Organization"), user: ref("User") } },
    Settings: { type: "object", properties: {
      auto_postpone_days: int, auto_done_days: int, default_look: str, mailbox_polling: bool, mailbox_poll_seconds: int,
      timeline_order: str, translation_enabled: bool, deepl_api_key_set: bool, google_ready: bool
    } },
    Report: { type: "object", description: "The numbers of the reports page.", properties: {
      period: str, unit: str(nil, enum: %w[day week month]), organization: nullable("Organization"), from: time, to: time,
      tiles: { type: "object" },
      buckets: { type: "array", items: { type: "object", properties: { starts_at: time, created: int, done: int } } },
      burndown: { type: "array", items: { type: "object", properties: { starts_at: time, open: int } } },
      statuses: { type: "array", items: { type: "object" } },
      organizations: { type: "array", items: { type: "object" } },
      people: { type: "array", items: { type: "object" } }
    } }
  }.freeze

  TICKET = wrap(:ticket, ref("TicketDetails"))
  COMMENT = wrap(:comment, ref("Comment"))
  TASK = { line: int("The line of the task in the text."), checked: bool }.freeze
  LIST_QUERY = {
    view: "A view of the queue or of \"My tickets\".", status: "Only this status.", priority: "Only this priority.",
    assignee: "Staff: `me`, `none` or a user id.", organization: "Staff: an organization id.", q: "Search text.",
    sort: "The sort order.", page: "The page, from 1; 25 tickets a page."
  }.freeze
  USER_BODY = { user: { type: "object", properties: {
    name: str, username: str, email: str, password: str("Write-only."), role: str(nil, enum: User::ROLES), deactivated: bool,
    organization_ids: { type: "array", items: int }
  } } }.freeze
  ORGANIZATION_BODY = { organization: { type: "object",
    description: "Name, notes, the public form and the mail settings, as on the organization's admin page. " \
                 "`smtp_password` and `imap_password` are write-only; left empty they stay as they are.",
    properties: { name: str, notes: str, public_form: bool, smtp_password: str("Write-only."), imap_password: str("Write-only.") },
    additionalProperties: true } }.freeze
  STAGE_BODY = { stage: { type: "object", properties: { status: { **STATUS, description: "Only when adding." }, name: str, color: str } } }.freeze
  STAGES = wrap(:stages, list("Stage"))

  # verb, path, tag, summary, options (query, body, multipart, returns, status, file)
  OPERATIONS = [
    [ "get", "/me", "Me", "The user of the token", { returns: wrap(:user, ref("Me")) } ],
    [ "patch", "/me", "Me", "Change the language; staff also the new-ticket notifications",
      { body: { user: { type: "object", properties: { language: str(nil, enum: %w[en bg de]), notify_new_tickets: bool } } },
        returns: wrap(:user, ref("Me")) } ],
    [ "get", "/tokens", "Me", "The user's own tokens, without secrets", { returns: wrap(:tokens, list("Token")) } ],
    [ "delete", "/tokens/{id}", "Me", "Revoke a token, also the one in use", { status: 204 } ],

    [ "get", "/tickets", "Tickets", "The ticket list, as the queue or \"My tickets\"",
      { query: LIST_QUERY, returns: { type: "object", properties: {
        tickets: list("Ticket"), view: str, page: int, total_pages: int, total_count: int
      } } } ],
    [ "post", "/tickets", "Tickets", "Open a ticket",
      { status: 201, multipart: true, returns: TICKET, body: { ticket: { type: "object", required: %w[subject], properties: {
        subject: str, description: str, markdown: bool, organization_id: int, requester_id: int("Staff only."),
        priority: PRIORITY, assignee_id: int("Staff only."),
        files: { type: "array", items: { type: "string", format: "binary" }, description: "As multipart, `ticket[files][]`." }
      } } } } ],
    [ "patch", "/tickets/bulk", "Tickets", "Staff: change many tickets at once",
      { body: {
          numbers: { type: "array", items: int }, scope: str("`list` to take every ticket of the list filters instead of numbers."),
          list: { type: "object", description: "The list filters: view, status, priority, assignee, organization, q." },
          changes: { type: "object", properties: { status: STATUS, priority: PRIORITY, assignee: str("`me`, `none` or a user id.") } },
          delete: bool("Delete the tickets instead.")
        },
        returns: { type: "object", properties: {
          updated: { type: "array", items: int }, unchanged: { type: "array", items: int },
          skipped: { type: "array", items: { type: "object", properties: { number: int, reason: str } } }
        } } } ],
    [ "get", "/tickets/{number}", "Tickets", "A ticket with its visible timeline, files and followers", { returns: TICKET } ],
    [ "patch", "/tickets/{number}", "Tickets", "Staff: change status, priority, assignee or stage",
      { returns: TICKET, body: { ticket: { type: "object", properties: {
        status: STATUS, priority: PRIORITY, assignee_id: { type: %w[integer null] }, stage_id: { type: %w[integer null] }
      } } } } ],
    [ "delete", "/tickets/{number}", "Tickets", "Staff who may update it: delete the ticket (it can be restored)", { status: 204 } ],
    [ "post", "/tickets/{number}/resolve", "Tickets", "The requester marks the ticket done", { returns: TICKET } ],
    [ "patch", "/tickets/{number}/description", "Tickets", "Edit the subject and description, or switch Markdown",
      { returns: TICKET, body: { ticket: { type: "object", properties: { subject: str, description: str, markdown: bool } } } } ],
    [ "patch", "/tickets/{number}/description/task", "Tickets", "Tick a task of the description's task list",
      { returns: TICKET, body: TASK } ],
    [ "get", "/tickets/{number}/comments", "Tickets", "The visible replies and notes", { returns: wrap(:comments, list("Comment")) } ],
    [ "post", "/tickets/{number}/comments", "Tickets", "Reply, or write an internal note (staff)",
      { status: 201, multipart: true, returns: COMMENT, body: { comment: { type: "object", required: %w[body], properties: {
        body: str, internal: bool("Staff only; from a requester it is a public reply."), markdown: bool,
        status: { **STATUS, description: "Staff only: the ticket's status after the reply." },
        files: { type: "array", items: { type: "string", format: "binary" }, description: "As multipart, `comment[files][]`." }
      } } } } ],
    [ "patch", "/tickets/{number}/comments/{id}", "Tickets", "Edit a reply or note, or switch Markdown",
      { returns: COMMENT, body: { comment: { type: "object", properties: { body: str, markdown: bool } } } } ],
    [ "patch", "/tickets/{number}/comments/{id}/task", "Tickets", "Tick a task of a reply's task list",
      { returns: COMMENT, body: TASK } ],
    [ "get", "/tickets/{number}/attachments/{id}", "Tickets", "Download a file of the ticket or of a visible reply", { file: true } ],
    [ "get", "/tickets/{number}/revisions", "Tickets", "Staff: earlier versions of the description and replies",
      { returns: wrap(:revisions, list("Revision")) } ],
    [ "post", "/tickets/{number}/revisions/{id}/restore", "Tickets", "Staff: bring an earlier version back", { returns: TICKET } ],
    [ "post", "/tickets/{number}/share", "Tickets", "Create or replace the share link",
      { status: 201, body: { password: str("Optional, 6 to 72 characters."), expires_in_days: int("Optional: 1, 7 or 30.") },
        returns: { type: "object", properties: { shared: bool, share_url: str, password: bool, expires_at: time } } } ],
    [ "delete", "/tickets/{number}/share", "Tickets", "Stop sharing", { status: 204 } ],
    [ "post", "/tickets/{number}/followers", "Tickets", "Add a staff follower or someone in Cc",
      { status: 201, returns: wrap(:follower, ref("Follower")),
        body: { user_id: int("Staff: a staff follower. The requester: a colleague for Cc."), email: str("Staff: an address for Cc.") } } ],
    [ "delete", "/tickets/{number}/followers/{id}", "Tickets", "Remove a follower, or leave Cc", { status: 204 } ],
    [ "post", "/tickets/{number}/translations", "Tickets", "Staff, when translation is on: translate a message",
      { body: { message: str("`description` or `comment-<id>`."), language: str("Default: the user's language.") },
        returns: wrap(:translation, { type: "object", properties: { source_language: str, target_language: str, text: str } }) } ],

    [ "get", "/notifications", "Notifications", "The user's notifications, newest first, 50 a page",
      { query: { page: "The page, from 1." },
        returns: { type: "object", properties: { notifications: list("Notification") }, additionalProperties: true } } ],
    [ "post", "/notifications/{id}/read", "Notifications", "Mark one read", { returns: wrap(:notification, ref("Notification")) } ],
    [ "post", "/notifications/read_all", "Notifications", "Mark all read" ],

    [ "get", "/reports", "Staff", "The numbers of the reports page",
      { query: { period: "7d, 30d, 90d, 12m or custom.", from: "For custom: YYYY-MM-DD.", to: "For custom: YYYY-MM-DD.",
                 organization: "An organization id." },
        returns: wrap(:report, ref("Report")) } ],
    [ "get", "/stages", "Staff", "The board's stages", { returns: STAGES } ],
    [ "get", "/people/{id}", "Staff", "A person's profile and ticket statistics",
      { returns: { type: "object", properties: { person: ref("User"), stats: { type: "object" }, recent: list("Ticket") } } } ],

    [ "post", "/stages", "Admin", "Add a board stage", { status: 201, body: STAGE_BODY, returns: wrap(:stage, ref("Stage")) } ],
    [ "patch", "/stages/{id}", "Admin", "Change a board stage", { body: STAGE_BODY, returns: wrap(:stage, ref("Stage")) } ],
    [ "delete", "/stages/{id}", "Admin", "Remove a board stage", { status: 204 } ],
    [ "post", "/stages/{id}/move", "Admin", "Move a stage up or down",
      { body: { direction: str(nil, enum: %w[up down]) }, returns: STAGES } ],
    [ "get", "/users", "Admin", "The users", { query: { role: "Only this role.", q: "Search text." },
                                              returns: wrap(:users, list("AdminUser")) } ],
    [ "post", "/users", "Admin", "Add a user", { status: 201, body: USER_BODY, returns: wrap(:user, ref("AdminUser")) } ],
    [ "get", "/users/{id}", "Admin", "A user", { returns: wrap(:user, ref("AdminUser")) } ],
    [ "patch", "/users/{id}", "Admin", "Change a user", { body: USER_BODY, returns: wrap(:user, ref("AdminUser")) } ],
    [ "delete", "/users/{id}", "Admin", "Remove a user without ticket history", { status: 204 } ],
    [ "get", "/organizations", "Admin", "The organizations", { query: { q: "Search text." },
                                                              returns: wrap(:organizations, list("Organization")) } ],
    [ "post", "/organizations", "Admin", "Add an organization",
      { status: 201, body: ORGANIZATION_BODY, returns: wrap(:organization, ref("OrganizationDetails")) } ],
    [ "get", "/organizations/{id}", "Admin", "An organization with its mail settings and members",
      { returns: wrap(:organization, ref("OrganizationDetails")) } ],
    [ "patch", "/organizations/{id}", "Admin", "Change an organization",
      { body: ORGANIZATION_BODY, returns: wrap(:organization, ref("OrganizationDetails")) } ],
    [ "delete", "/organizations/{id}", "Admin", "Remove an organization", { status: 204 } ],
    [ "post", "/organizations/{id}/mail_test", "Admin", "Send a test email through the organization's SMTP",
      { returns: { type: "object", properties: { sent_to: str } } } ],
    [ "post", "/organizations/{id}/mailbox_check", "Admin", "Check the organization's mailbox",
      { returns: { type: "object", properties: { unseen: int } } } ],
    [ "post", "/organizations/{id}/flush", "Admin", "Remove all tickets of the organization for good",
      { body: { confirm_name: str("The organization's exact name.") }, returns: { type: "object", properties: { removed: { type: "object" } } } } ],
    [ "post", "/organizations/{organization_id}/memberships", "Admin", "Add one or many members",
      { status: 201, body: { membership: { type: "object", properties: { user_id: int } },
                             user_ids: { type: "array", items: int, description: "Several users at once, instead of membership." } } } ],
    [ "patch", "/memberships/{id}", "Admin", "Set or clear the organization administrator mark of an agent",
      { body: { membership: { type: "object", properties: { admin: bool } } },
        returns: wrap(:membership, ref("Membership")) } ],
    [ "delete", "/memberships/{id}", "Admin", "Remove a member", { status: 204 } ],
    [ "get", "/settings", "Admin", "The application settings", { returns: wrap(:settings, ref("Settings")) } ],
    [ "patch", "/settings", "Admin", "Change the application settings",
      { returns: wrap(:settings, ref("Settings")),
        body: { settings: { type: "object", properties: {
          auto_postpone_days: int, auto_done_days: int, default_look: str, mailbox_polling: bool, mailbox_poll_seconds: int,
          timeline_order: str, translation_enabled: bool, deepl_api_key: str("Write-only.")
        } } } } ],
    [ "post", "/messages", "Admin", "Send a message to users' notifications",
      { status: 201, body: { message: { type: "object", properties: { recipients: str, text: str } } }, returns: { type: "object", properties: { delivered: int } } } ],
    [ "get", "/deleted_tickets", "Admin", "Deleted tickets of the administrator's organizations",
      { returns: wrap(:tickets, list("Ticket")) } ],
    [ "post", "/deleted_tickets/{number}/restore", "Admin", "Bring a deleted ticket back", { returns: TICKET } ]
  ].freeze
end
