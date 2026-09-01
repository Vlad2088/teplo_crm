class AddDiscountPercentToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :discount_percent, :decimal, precision: 5, scale: 2, null: false, default: 0
    add_check_constraint :orders, "discount_percent >= 0 AND discount_percent <= 100", name: "orders_discount_percent_range"
  end
end
