class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.text :comment
      t.date :due_date
      t.integer :priority, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.datetime :completed_at
      t.references :user, null: false, foreign_key: true
      t.string :source, default: "web", null: false

      t.timestamps
    end
    add_index :tasks, :status
    add_index :tasks, :due_date
  end
end
