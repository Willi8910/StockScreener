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

ActiveRecord::Schema.define(version: 2023_07_22_072345) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "external_services", force: :cascade do |t|
    t.string "name"
    t.string "access_token"
    t.datetime "last_update_access_token", precision: 6
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "yog"
    t.integer "yoc"
    t.datetime "obligation_last_updated", precision: 6
  end

  create_table "histories", force: :cascade do |t|
    t.string "name"
    t.text "data"
    t.integer "search_count", default: 1
    t.integer "search_monthly", default: 1
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "cid"
    t.integer "tid"
    t.string "full_name"
  end

  create_table "stock_recommends", force: :cascade do |t|
    t.bigint "history_id"
    t.decimal "rating"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["history_id"], name: "index_stock_recommends_on_history_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.string "name"
    t.integer "value"
    t.integer "pb_fair_value"
    t.integer "pe_fair_value"
    t.integer "benjamin_fair_value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.string "chart"
    t.boolean "favourite", default: false
    t.index ["user_id"], name: "index_stocks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: 6
    t.datetime "remember_created_at", precision: 6
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "jti", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "stocks", "users"
end
