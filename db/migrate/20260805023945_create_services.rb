class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name
      t.decimal :price_per_sqm
      t.text :description

      t.timestamps
    end
  end
end
