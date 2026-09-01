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

  validates :client, presence: true
  validates :user, presence: true
  validates :status, presence: true
  validates :address, presence: true
  validates :area_sqm, numericality: { greater_than: 0 }, allow_nil: true
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Сумма позиций до скидки
  def items_total
    order_items.sum(:total_price)
  end

  # Сумма скидки в рублях
  def discount_amount
    items_total * discount_percent / 100
  end

  # Итого к оплате с учётом скидки
  def total_due
    items_total - discount_amount
  end

  # Уже оплачено
  def paid_total
    payments.sum(:amount)
  end

  # Осталось оплатить
  def balance_due
    total_due - paid_total
  end
end
