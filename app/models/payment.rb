class Payment < ApplicationRecord
  belongs_to :order

  enum :payment_type, { cash: 0, cashless: 1 }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
  validates :payment_type, presence: true
end
