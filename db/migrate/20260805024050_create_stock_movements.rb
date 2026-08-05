class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :quantity_change
      t.integer :movement_type
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
