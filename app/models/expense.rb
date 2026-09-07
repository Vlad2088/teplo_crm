class Expense < ApplicationRecord
  belongs_to :expense_category
  belongs_to :user

  enum :payment_method, { cash: 0, cashless: 1 }

  has_one_attached :receipt

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :spent_on, presence: true
  validates :payment_method, presence: true

  default_scope -> { order(spent_on: :desc, id: :desc) }

  scope :for_period, ->(from, to) { where(spent_on: from..to) }
end
