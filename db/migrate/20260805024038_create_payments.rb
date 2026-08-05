class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.decimal :amount
      t.datetime :paid_at
      t.integer :payment_type
      t.string :description

      t.timestamps
    end
  end
end
