class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :order, null: false, foreign_key: true
      t.integer :doc_type
      t.string :title
      t.text :content
      t.string :file_path

      t.timestamps
    end
  end
end
