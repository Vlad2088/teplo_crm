class StockMovement < ApplicationRecord
  belongs_to :product
  belongs_to :order, optional: true  # приход может быть без заказа

  enum :movement_type, { in: 0, out: 1 }

  validates :product, presence: true
  validates :quantity_change, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :movement_type, presence: true

  after_create :update_product_stock!

  private

  def update_product_stock!
    if self.in?
      product.increment!(:stock_quantity, quantity_change)
    else
      product.decrement!(:stock_quantity, quantity_change)
    end
  end
end
