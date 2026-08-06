class Service < ApplicationRecord
  has_many :order_items, as: :item

  validates :name, presence: true
  validates :price_per_sqm, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
