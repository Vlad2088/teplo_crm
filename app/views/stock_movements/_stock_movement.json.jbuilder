json.extract! stock_movement, :id, :product_id, :quantity_change, :movement_type, :order_id, :created_at, :updated_at
json.url stock_movement_url(stock_movement, format: :json)
