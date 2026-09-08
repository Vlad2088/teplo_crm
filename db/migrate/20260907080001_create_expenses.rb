class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :spent_on, null: false
      t.integer :payment_method, null: false, default: 0
      t.string :comment
      t.references :expense_category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :expenses, :spent_on
  end
end
