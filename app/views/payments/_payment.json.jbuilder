json.extract! payment, :id, :order_id, :amount, :paid_at, :payment_type, :description, :created_at, :updated_at
json.url payment_url(payment, format: :json)
