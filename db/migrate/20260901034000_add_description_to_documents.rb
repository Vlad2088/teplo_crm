class AddDescriptionToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :description, :text
  end
end
