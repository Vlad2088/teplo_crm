class AddDocumentDateToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :document_date, :date
  end
end
