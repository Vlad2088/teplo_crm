class Payment < ApplicationRecord
  belongs_to :order

  enum :payment_type, { cash: 0, cashless: 1 }
end
