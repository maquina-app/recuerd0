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

ActiveRecord::Schema[8.0].define(version: 2026_02_04_180309) do
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
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.datetime "archived_at"
    t.integer "memories_count", default: 0, null: false
    t.index ["archived_at"], name: "index_workspaces_on_archived_at"
    t.index ["deleted_at"], name: "index_workspaces_on_deleted_at"
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "contents", "memories"
  add_foreign_key "memories", "memories", column: "parent_memory_id"
  add_foreign_key "memories", "workspaces"
  add_foreign_key "pins", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "workspaces", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "memories_search", "fts5", ["title", "body", "memory_id UNINDEXED", "tokenize='trigram'"]
end
