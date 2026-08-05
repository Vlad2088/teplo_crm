class Document < ApplicationRecord
  belongs_to :order

  enum :doc_type, { estimate: 0, invoice: 1, act: 2, contract: 3, upd: 4 }
end
