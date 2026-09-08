class CreateExpenseCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :expense_categories, :name, unique: true
  end
end
