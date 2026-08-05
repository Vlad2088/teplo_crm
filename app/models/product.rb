class Product < ApplicationRecord
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :order_items, as: :item   # полиморфная связь для OrderItem

  enum :category, { warm_floor: 0, thermostat: 1, underlay: 2, other: 3 }
  enum :brand, { tesla: 0, xl_pipe: 1, other: 2 }
end
