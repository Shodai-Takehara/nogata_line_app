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

ActiveRecord::Schema[8.0].define(version: 2025_04_23_080135) do
  create_table "campgrounds", force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_campgrounds_on_name", unique: true
  end

  create_table "reservation_job_executions", force: :cascade do |t|
    t.integer "campground_id", null: false
    t.datetime "executed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campground_id", "executed_at"], name: "idx_on_campground_id_executed_at_7955e26cbd", unique: true
    t.index ["campground_id"], name: "index_reservation_job_executions_on_campground_id"
  end

  create_table "reservation_slots", force: :cascade do |t|
    t.integer "reservation_job_execution_id", null: false
    t.integer "site_id", null: false
    t.date "date", null: false
    t.time "time_slot", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_job_execution_id"], name: "index_reservation_slots_on_reservation_job_execution_id"
    t.index ["site_id", "date", "time_slot", "reservation_job_execution_id"], name: "index_reservation_slots_on_site_and_datetime_and_exec", unique: true
    t.index ["site_id"], name: "index_reservation_slots_on_site_id"
  end

  create_table "site_types", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_site_types_on_name", unique: true
  end

  create_table "sites", force: :cascade do |t|
    t.integer "campground_id", null: false
    t.integer "site_type_id", null: false
    t.integer "site_no", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campground_id", "site_no"], name: "index_sites_on_campground_id_and_site_no", unique: true
    t.index ["campground_id"], name: "index_sites_on_campground_id"
    t.index ["site_no"], name: "index_sites_on_site_no"
    t.index ["site_type_id"], name: "index_sites_on_site_type_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "line_user_id", null: false
    t.string "name"
    t.string "profile_image_url"
    t.string "email"
    t.string "status_message"
    t.boolean "is_active", default: true
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["line_user_id"], name: "index_users_on_line_user_id", unique: true
  end

  add_foreign_key "reservation_job_executions", "campgrounds"
  add_foreign_key "reservation_slots", "reservation_job_executions"
  add_foreign_key "reservation_slots", "sites"
  add_foreign_key "sites", "campgrounds"
  add_foreign_key "sites", "site_types"
end
