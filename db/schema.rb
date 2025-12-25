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

ActiveRecord::Schema[8.1].define(version: 2025_12_25_180416) do
  create_table "accounts", force: :cascade do |t|
    t.integer "account_type", default: 0, null: false
    t.date "balance_date", null: false
    t.datetime "created_at", null: false
    t.decimal "current_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.decimal "warning_threshold", precision: 12, scale: 2, default: "300.0", null: false
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.string "ip_address"
    t.integer "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
  end

  create_table "categories", force: :cascade do |t|
    t.integer "category_group_id", null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category_group_id", "display_order"], name: "index_categories_on_category_group_id_and_display_order"
    t.index ["category_group_id", "name"], name: "index_categories_on_category_group_id_and_name", unique: true
    t.index ["category_group_id"], name: "index_categories_on_category_group_id"
  end

  create_table "category_groups", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_category_groups_on_name", unique: true
  end

  create_table "recurring_rules", force: :cascade do |t|
    t.integer "account_id", null: false
    t.boolean "active", default: true, null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.date "anchor_date", null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "description", null: false
    t.integer "destination_account_id"
    t.integer "frequency", default: 0, null: false
    t.boolean "is_estimated", default: true, null: false
    t.integer "rule_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_recurring_rules_on_account_id"
    t.index ["category_id"], name: "index_recurring_rules_on_category_id"
    t.index ["destination_account_id"], name: "index_recurring_rules_on_destination_account_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "auth_password_digest"
    t.string "auth_username"
    t.datetime "created_at", null: false
    t.integer "default_view_months", default: 6, null: false
    t.integer "session_timeout_minutes", default: 30, null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.integer "linked_transaction_id"
    t.integer "recurring_rule_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "user_modified", default: false, null: false
    t.index ["account_id", "date"], name: "index_transactions_on_account_id_and_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["linked_transaction_id"], name: "index_transactions_on_linked_transaction_id"
    t.index ["recurring_rule_id", "account_id", "date"], name: "index_transactions_on_rule_account_date_unique", unique: true, where: "recurring_rule_id IS NOT NULL"
    t.index ["recurring_rule_id"], name: "index_transactions_on_recurring_rule_id"
  end

  add_foreign_key "categories", "category_groups"
  add_foreign_key "recurring_rules", "accounts"
  add_foreign_key "recurring_rules", "accounts", column: "destination_account_id"
  add_foreign_key "recurring_rules", "categories"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "recurring_rules"
  add_foreign_key "transactions", "transactions", column: "linked_transaction_id"
end
