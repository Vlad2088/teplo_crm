class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string :item_type
      t.integer :item_id
      t.decimal :quantity
      t.decimal :unit_price
      t.decimal :total_price

      t.timestamps
    end
  end
end
