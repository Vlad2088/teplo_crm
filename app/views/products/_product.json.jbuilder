json.extract! product, :id, :name, :sku, :category, :brand, :unit, :purchase_price, :sale_price, :stock_quantity, :created_at, :updated_at
json.url product_url(product, format: :json)
