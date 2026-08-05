class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.integer :type
      t.string :name
      t.string :phone
      t.string :email
      t.text :address
      t.string :inn
      t.string :kpp

      t.timestamps
    end
  end
end
