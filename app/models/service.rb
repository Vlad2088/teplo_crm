class Service < ApplicationRecord
  has_many :order_items, as: :item
end
