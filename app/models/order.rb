class Order < ApplicationRecord
  belongs_to :client
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :stock_movements, dependent: :destroy  # если движение склада связано с заказом

  enum :status, {
    lead: 0, measurement: 1, estimate: 2,
    contract_signed: 3, materials_paid: 4,
    installation: 5, act_signed: 6,
    installation_paid: 7, completed: 8, cancelled: 9
  }
end
