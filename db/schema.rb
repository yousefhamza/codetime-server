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

ActiveRecord::Schema[8.1].define(version: 2026_01_12_102019) do
  create_table "event_logs", force: :cascade do |t|
    t.string "absolute_file"
    t.datetime "created_at", null: false
    t.string "editor"
    t.datetime "event_time"
    t.string "event_type"
    t.string "git_branch"
    t.string "git_origin"
    t.string "language"
    t.string "operation_type"
    t.string "platform"
    t.string "platform_arch"
    t.string "project"
    t.string "relative_file"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "event_time"], name: "index_event_logs_on_user_id_and_event_time"
    t.index ["user_id"], name: "index_event_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  add_foreign_key "event_logs", "users"
end
