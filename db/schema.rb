# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_130000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.integer "auto_postpone_days", default: 30, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "translation_enabled", default: false, null: false
    t.text "deepl_api_key"
    t.string "google_client_id"
    t.text "google_client_secret"
    t.string "default_look", default: "notes", null: false
    t.boolean "mailbox_polling", default: false, null: false
    t.integer "mailbox_poll_seconds", default: 120, null: false
  end

  create_table "comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "author_id", null: false
    t.text "body", null: false
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "edited_at"
    t.integer "edited_by_id"
    t.boolean "markdown", default: false, null: false
    t.string "source", default: "app", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["edited_by_id"], name: "index_comments_on_edited_by_id"
    t.index ["ticket_id", "created_at"], name: "index_comments_on_ticket_id_and_created_at"
  end

  create_table "impersonations", force: :cascade do |t|
    t.integer "admin_id", null: false
    t.integer "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.string "ip"
    t.index ["admin_id"], name: "index_impersonations_on_admin_id"
    t.index ["user_id", "started_at"], name: "index_impersonations_on_user_id_and_started_at"
  end

  create_table "mail_connections", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "provider", null: false
    t.string "email", null: false
    t.text "refresh_token", null: false
    t.string "status", default: "connected", null: false
    t.datetime "connected_at", null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_mail_connections_on_organization_id", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "ticket_id"
    t.integer "actor_id"
    t.integer "event_id"
    t.string "kind", null: false
    t.string "status"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "message"
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["ticket_id"], name: "index_notifications_on_ticket_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.check_constraint "ticket_id IS NOT NULL OR message IS NOT NULL", name: "notifications_ticket_or_message"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "smtp_enabled", default: false, null: false
    t.string "smtp_address"
    t.integer "smtp_port", default: 587, null: false
    t.string "smtp_security", default: "starttls", null: false
    t.string "smtp_username"
    t.text "smtp_password"
    t.string "mail_from"
    t.boolean "imap_enabled", default: false, null: false
    t.string "imap_address"
    t.integer "imap_port", default: 993, null: false
    t.boolean "imap_ssl", default: true, null: false
    t.string "imap_username"
    t.text "imap_password"
    t.string "imap_folder", default: "INBOX", null: false
    t.string "mailbox_address"
    t.datetime "imap_last_checked_at"
    t.text "imap_last_error"
    t.integer "imap_messages_count", default: 0, null: false
    t.string "slug"
    t.boolean "public_form", default: false, null: false
    t.text "public_intro"
    t.text "public_allowed_senders"
    t.string "mail_auth", default: "password", null: false
    t.index "lower(name)", name: "index_organizations_on_lower_name", unique: true
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "revisions", force: :cascade do |t|
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "editor_id", null: false
    t.string "subject"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.index ["editor_id"], name: "index_revisions_on_editor_id"
    t.index ["record_type", "record_id", "created_at"], name: "index_revisions_on_record_type_and_record_id_and_created_at"
  end

  create_table "stages", force: :cascade do |t|
    t.string "status", null: false
    t.string "name", null: false
    t.string "color", default: "gray", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "position"], name: "index_stages_on_status_and_position"
  end

  create_table "ticket_events", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "actor_id"
    t.string "action", null: false
    t.string "from_value"
    t.string "to_value"
    t.integer "comment_id"
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_ticket_events_on_actor_id"
    t.index ["comment_id"], name: "index_ticket_events_on_comment_id"
    t.index ["ticket_id", "created_at"], name: "index_ticket_events_on_ticket_id_and_created_at"
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "number", null: false
    t.string "subject", null: false
    t.text "description", null: false
    t.string "status", default: "new", null: false
    t.string "priority", default: "normal", null: false
    t.integer "requester_id", null: false
    t.integer "assignee_id"
    t.integer "organization_id", null: false
    t.datetime "done_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_token"
    t.string "share_password_digest"
    t.datetime "shared_at"
    t.datetime "edited_at"
    t.integer "edited_by_id"
    t.boolean "markdown", default: false, null: false
    t.string "source", default: "app", null: false
    t.integer "stage_id"
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["edited_by_id"], name: "index_tickets_on_edited_by_id"
    t.index ["number"], name: "index_tickets_on_number", unique: true
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["requester_id"], name: "index_tickets_on_requester_id"
    t.index ["share_token"], name: "index_tickets_on_share_token", unique: true
    t.index ["stage_id"], name: "index_tickets_on_stage_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["updated_at"], name: "index_tickets_on_updated_at"
  end

  create_table "translations", force: :cascade do |t|
    t.string "translatable_type", null: false
    t.integer "translatable_id", null: false
    t.string "target_language", null: false
    t.string "source_language", null: false
    t.text "text", null: false
    t.string "source_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_type", "translatable_id", "target_language"], name: "index_translations_on_message_and_language", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "username"
    t.string "name"
    t.string "role", default: "requester", null: false
    t.datetime "deactivated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale"
    t.boolean "notify_new_tickets", default: false, null: false
    t.boolean "password_chosen", default: true, null: false
    t.string "language"
    t.index "lower(username)", name: "index_users_on_lower_username", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "tickets"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "comments", "users", column: "edited_by_id"
  add_foreign_key "impersonations", "users"
  add_foreign_key "impersonations", "users", column: "admin_id"
  add_foreign_key "mail_connections", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "notifications", "ticket_events", column: "event_id"
  add_foreign_key "notifications", "tickets"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "revisions", "users", column: "editor_id"
  add_foreign_key "ticket_events", "comments"
  add_foreign_key "ticket_events", "tickets"
  add_foreign_key "ticket_events", "users", column: "actor_id"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "stages", on_delete: :nullify
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "edited_by_id"
  add_foreign_key "tickets", "users", column: "requester_id"
end
