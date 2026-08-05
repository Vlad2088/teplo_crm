class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :sku
      t.integer :category
      t.integer :brand
      t.string :unit
      t.decimal :purchase_price
      t.decimal :sale_price
      t.integer :stock_quantity

      t.timestamps
    end
  end
end
