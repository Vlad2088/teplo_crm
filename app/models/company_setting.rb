class CompanySetting < ApplicationRecord
  validates :name, presence: true

  # Единственная запись настроек (создаётся при первом обращении)
  def self.current
    first || create!(name: "ИП — заполните реквизиты")
  end
end
