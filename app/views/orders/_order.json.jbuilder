json.extract! order, :id, :client_id, :status, :address, :area_sqm, :measurement_date, :notes, :user_id, :created_at, :updated_at
json.url order_url(order, format: :json)
