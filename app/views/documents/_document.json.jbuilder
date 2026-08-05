json.extract! document, :id, :order_id, :doc_type, :title, :content, :file_path, :created_at, :updated_at
json.url document_url(document, format: :json)
