class MakeOrderIdNullableInStockMovements < ActiveRecord::Migration[8.1]
  def change
    change_column_null :stock_movements, :order_id, true
  end
end
