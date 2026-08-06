class Product < ApplicationRecord
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :order_items, as: :item   # полиморфная связь для OrderItem

  enum :category, { warm_floor: 0, thermostat: 1, underlay: 2, other: 3 }
  enum :brand, { tesla: 0, xl_pipe: 1, other_brand: 2 }

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :sale_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :category, presence: true
  validates :brand, presence: true
  validates :unit, presence: true
end
