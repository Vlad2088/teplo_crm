class Client < ApplicationRecord
  has_many :orders, dependent: :restrict_with_error

  enum :client_type, { individual: 0, entrepreneur: 1, legal_entity: 2 }
  enum :gender, { male: 0, female: 1 }

  validates :name, presence: true
  validates :phone, presence: true
  validates :client_type, presence: true

  # Форматные проверки — мягкие: пустое поле не валидируется,
  # заполненное должно соответствовать формату
  validates :inn, length: { is: 12 }, if: -> { individual? && inn.present? }
  validates :inn, length: { is: 12 }, if: -> { entrepreneur? && inn.present? }
  validates :inn, length: { is: 10 }, if: -> { legal_entity? && inn.present? }
  validates :ogrn, length: { is: 15 }, if: -> { entrepreneur? && ogrn.present? }
  validates :ogrn, length: { is: 13 }, if: -> { legal_entity? && ogrn.present? }
  validates :passport_series, format: { with: /\A\d{4}\z/ }, if: -> { individual? && passport_series.present? }
  validates :passport_number, format: { with: /\A\d{6}\z/ }, if: -> { individual? && passport_number.present? }
  validates :bank_bik, format: { with: /\A\d{9}\z/ }, if: -> { bank_bik.present? }

  # Имя для документов и списков
  def display_name
    individual? ? name.to_s : short_name.presence || name.to_s
  end

  # Реквизиты для печатных форм (по типу клиента)
  def requisites_lines
    lines = []
    case client_type
    when "individual"
      lines << "Паспорт: #{passport_series} №#{passport_number}" if passport_series.present? || passport_number.present?
      lines << "Выдан: #{passport_issued_by} #{l_date(passport_issued_on)}" if passport_issued_by.present?
      lines << "Адрес регистрации: #{registration_address}" if registration_address.present?
    when "entrepreneur"
      lines << "ИНН #{inn}" if inn.present?
      lines << "ОГРНИП #{ogrn}" if ogrn.present?
      lines << "ОКПО #{okpo}" if okpo.present?
      lines << "ОКВЭД #{okved}" if okved.present?
      lines += bank_lines
      lines << "Адрес: #{registration_address || address}" if registration_address.present? || address.present?
    when "legal_entity"
      lines << "ИНН #{inn}, КПП #{kpp}" if inn.present?
      lines << "ОГРН #{ogrn}" if ogrn.present?
      lines << "ОКПО #{okpo}, ОКВЭД #{okved}" if okpo.present? || okved.present?
      lines << "Юр. адрес: #{address}" if address.present?
      lines += bank_lines
      lines << "#{director_position} #{director_name}" if director_name.present?
    end
    lines
  end

  private

    def bank_lines
      return [] if bank_name.blank? && bank_account.blank?
      [ "Р/с #{bank_account}" ].tap do |arr|
        arr << "Банк: #{bank_name}, БИК #{bank_bik}" if bank_name.present?
        arr << "К/с #{bank_corr_account}" if bank_corr_account.present?
      end.compact
    end

    def l_date(date)
      I18n.l(date, format: :long)
    rescue StandardError
      date.to_s
    end
end
