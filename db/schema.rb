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

ActiveRecord::Schema[8.1].define(version: 2026_09_01_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clients", force: :cascade do |t|
    t.text "address"
    t.integer "client_type"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "inn"
    t.string "kpp"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
  end

  create_table "company_settings", force: :cascade do |t|
    t.string "address"
    t.string "bank_account"
    t.string "bank_bik"
    t.string "bank_corr_account"
    t.string "bank_name"
    t.datetime "created_at", null: false
    t.string "director_name"
    t.string "email"
    t.string "inn"
    t.string "kpp"
    t.string "name", null: false
    t.string "phone"
    t.string "position_title", default: "Индивидуальный предприниматель"
    t.datetime "updated_at", null: false
  end

  create_table "documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "doc_type"
    t.date "document_date"
    t.string "file_path"
    t.bigint "order_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_documents_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "item_id"
    t.string "item_type"
    t.bigint "order_id", null: false
    t.decimal "quantity"
    t.decimal "total_price"
    t.decimal "unit_price"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.text "address"
    t.decimal "area_sqm"
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.decimal "discount_percent", precision: 5, scale: 2, default: "0.0", null: false
    t.date "measurement_date"
    t.text "notes"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "discount_percent >= 0::numeric AND discount_percent <= 100::numeric", name: "orders_discount_percent_range"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "order_id", null: false
    t.datetime "paid_at"
    t.integer "payment_type"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "brand"
    t.integer "category"
    t.datetime "created_at", null: false
    t.string "name"
    t.decimal "purchase_price"
    t.decimal "sale_price"
    t.string "sku"
    t.integer "stock_quantity"
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.decimal "price_per_sqm"
    t.datetime "updated_at", null: false
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "movement_type"
    t.bigint "order_id"
    t.bigint "product_id", null: false
    t.integer "quantity_change"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_stock_movements_on_order_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "documents", "orders"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "clients"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "orders"
  add_foreign_key "stock_movements", "orders"
  add_foreign_key "stock_movements", "products"
end
