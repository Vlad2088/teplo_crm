class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :client, null: false, foreign_key: true
      t.integer :status
      t.text :address
      t.decimal :area_sqm
      t.date :measurement_date
      t.text :notes
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
