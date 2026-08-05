class StockMovement < ApplicationRecord
  belongs_to :product
  belongs_to :order, optional: true  # приход может быть без заказа

  enum :movement_type, { in: 0, out: 1 }
end
