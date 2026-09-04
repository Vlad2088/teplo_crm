class Document < ApplicationRecord
  belongs_to :order

  enum :doc_type, { estimate: 0, invoice: 1, act: 2, contract: 3, upd: 4, torg12: 5, contract_work: 6, contract_supply: 7 }

  validates :doc_type, presence: true
  validates :title, presence: true
end
