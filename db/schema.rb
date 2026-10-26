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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_202818) do
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

  create_table "comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "author_id", null: false
    t.text "body", null: false
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["ticket_id", "created_at"], name: "index_comments_on_ticket_id_and_created_at"
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
    t.integer "ticket_id", null: false
    t.integer "actor_id"
    t.integer "event_id"
    t.string "kind", null: false
    t.string "status"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["ticket_id"], name: "index_notifications_on_ticket_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower(name)", name: "index_organizations_on_lower_name", unique: true
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
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_token"
    t.string "share_password_digest"
    t.datetime "shared_at"
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["number"], name: "index_tickets_on_number", unique: true
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["requester_id"], name: "index_tickets_on_requester_id"
    t.index ["share_token"], name: "index_tickets_on_share_token", unique: true
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["updated_at"], name: "index_tickets_on_updated_at"
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
    t.index "lower(username)", name: "index_users_on_lower_username", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "tickets"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "notifications", "ticket_events", column: "event_id"
  add_foreign_key "notifications", "tickets"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "ticket_events", "comments"
  add_foreign_key "ticket_events", "tickets"
  add_foreign_key "ticket_events", "users", column: "actor_id"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "requester_id"
end
