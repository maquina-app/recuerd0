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

ActiveRecord::Schema[8.0].define(version: 2026_02_06_005859) do
  create_table "access_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.string "description"
    t.string "permission", default: "read_only", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_access_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_accounts_on_deleted_at"
  end

  create_table "analytics_api_requests", force: :cascade do |t|
    t.integer "account_id"
    t.integer "user_id"
    t.integer "access_token_id"
    t.string "http_method", null: false
    t.string "path", null: false
    t.integer "status", null: false
    t.integer "duration_ms"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["access_token_id", "created_at"], name: "idx_analytics_api_requests_token_time"
    t.index ["account_id", "created_at"], name: "idx_analytics_api_requests_account_time"
    t.index ["path", "http_method", "created_at"], name: "idx_analytics_api_requests_endpoint_time"
  end

  create_table "analytics_events", force: :cascade do |t|
    t.integer "account_id"
    t.integer "user_id"
    t.string "event_type", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.json "metadata"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["account_id", "event_type", "created_at"], name: "idx_analytics_events_account_type_time"
    t.index ["resource_type", "resource_id"], name: "idx_analytics_events_resource"
    t.index ["user_id", "created_at"], name: "idx_analytics_events_user_time"
  end

  create_table "contents", force: :cascade do |t|
    t.text "body"
    t.integer "memory_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_contents_on_memory_id"
  end

  create_table "memories", force: :cascade do |t|
    t.string "title"
    t.text "tags"
    t.string "source"
    t.integer "workspace_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.integer "parent_memory_id"
    t.index ["parent_memory_id", "version"], name: "index_memories_on_parent_memory_id_and_version"
    t.index ["parent_memory_id"], name: "index_memories_on_parent_memory_id"
    t.index ["version"], name: "index_memories_on_version"
    t.index ["workspace_id"], name: "index_memories_on_workspace_id"
  end

  create_table "pins", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "pinnable_type", null: false
    t.integer "pinnable_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pinnable_type", "pinnable_id"], name: "index_pins_on_pinnable"
    t.index ["user_id", "pinnable_type", "pinnable_id"], name: "index_pins_uniqueness", unique: true
    t.index ["user_id", "pinnable_type", "position"], name: "index_pins_user_type_position"
    t.index ["user_id"], name: "index_pins_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "account_id", null: false
    t.string "role", default: "member", null: false
    t.string "name"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.datetime "archived_at"
    t.integer "memories_count", default: 0, null: false
    t.integer "account_id", null: false
    t.index ["account_id"], name: "index_workspaces_on_account_id"
    t.index ["archived_at"], name: "index_workspaces_on_archived_at"
    t.index ["deleted_at"], name: "index_workspaces_on_deleted_at"
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "contents", "memories"
  add_foreign_key "memories", "memories", column: "parent_memory_id"
  add_foreign_key "memories", "workspaces"
  add_foreign_key "pins", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "accounts"
  add_foreign_key "workspaces", "accounts"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "memories_search", "fts5", ["title", "body", "memory_id UNINDEXED", "tokenize='trigram'"]
end
