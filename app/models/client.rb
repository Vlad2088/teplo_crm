class Client < ApplicationRecord
  has_many :orders, dependent: :restrict_with_error

  enum :client_type, { individual: 0, entrepreneur: 1, legal_entity: 2 }
end
