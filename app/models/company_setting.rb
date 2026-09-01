class CompanySetting < ApplicationRecord
  enum :company_type, { individual_enterpreneur: 0, legal_entity: 1 }

  validates :name, presence: true
  validates :inn, length: { is: 12 }, if: -> { individual_enterpreneur? && inn.present? }
  validates :inn, length: { is: 10 }, if: -> { legal_entity? && inn.present? }
  validates :ogrn, length: { is: 15 }, if: -> { individual_enterpreneur? && ogrn.present? }
  validates :ogrn, length: { is: 13 }, if: -> { legal_entity? && ogrn.present? }
  validates :bank_bik, format: { with: /\A\d{9}\z/ }, if: -> { bank_bik.present? }

  # Единственная запись настроек (создаётся при первом обращении)
  def self.current
    first || create!(name: "ИП — заполните реквизиты")
  end

  # Реквизиты для печатных форм
  def requisites_lines
    lines = []
    if individual_enterpreneur?
      lines << "ИНН #{inn}" if inn.present?
      lines << "ОГРНИП #{ogrn}" if ogrn.present?
      lines << "ОКПО #{okpo}" if okpo.present?
    else
      lines << "ИНН #{inn}, КПП #{kpp}" if inn.present?
      lines << "ОГРН #{ogrn}" if ogrn.present?
    end
    lines << address if address.present?
    lines += bank_lines
    lines
  end

  # Подпись в печатных формах: «ИП Иванов И.И.» или «Директор ООО Ромашка»
  def signature_caption
    if individual_enterpreneur?
      "ИП #{director_name.presence || name}"
    else
      "#{position_title.presence || 'Руководитель'} #{short_name.presence || name}"
    end
  end

  private

    def bank_lines
      return [] if bank_name.blank? && bank_account.blank?
      [ "Р/с #{bank_account} в #{bank_name}" ].tap do |arr|
        arr << "БИК #{bank_bik}, к/с #{bank_corr_account}" if bank_bik.present?
      end.compact
    end
end
