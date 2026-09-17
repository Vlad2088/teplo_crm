class Order < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :organization
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

  # Статусы, в которых заказ держит товар на складе:
  # вход в диапазон — списание всех товарных позиций, выход — возврат.
  STOCK_CONTROLLED_STATUSES = %w[
    contract_signed materials_paid installation act_signed installation_paid completed
  ].freeze

  before_validation :set_default_organization, on: :create

  validates :client, presence: true
  validates :user, presence: true
  validates :organization, presence: true
  validates :status, presence: true
  validates :address, presence: true
  validates :area_sqm, numericality: { greater_than: 0 }, allow_nil: true
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :stock_available_for_transition, on: :update, if: :transitioning_into_stock_controlled?

  after_update :sync_stock_with_status, if: :saved_change_to_status?

  # Управляет ли заказ складом в текущем статусе
  def stock_controlled?
    STOCK_CONTROLLED_STATUSES.include?(status.to_s)
  end

  # Дефициты товара при переводе в «реальный» статус: [[product, needed, available], ...]
  def stock_deficits
    order_items.includes(:item)
               .select { |oi| oi.product_item? && !oi.stock_withdrawn? && oi.item }
               .group_by(&:item)
               .filter_map do |product, items|
                 needed = items.sum(&:quantity).to_i
                 [ product, needed, product.stock_quantity ] if product.stock_quantity < needed
               end
  end

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

  private

    def set_default_organization
      self.organization ||= Organization.default
    end

    # Перевод из черновика/отмены в «реальный» статус
    def transitioning_into_stock_controlled?
      return false unless status_changed?

      stock_controlled? && !STOCK_CONTROLLED_STATUSES.include?(status_was.to_s)
    end

    def stock_available_for_transition
      stock_deficits.each do |product, needed, available|
        errors.add(:status, "— не хватает товара «#{product.name}»: на складе #{available}, нужно #{needed}")
      end
    end

    # Списание/возврат товара при смене статусного диапазона
    def sync_stock_with_status
      old_status, new_status = saved_change_to_status
      was_controlled = STOCK_CONTROLLED_STATUSES.include?(old_status)
      now_controlled = STOCK_CONTROLLED_STATUSES.include?(new_status)
      return if was_controlled == now_controlled

      if now_controlled
        order_items.find_each(&:withdraw_from_stock!)
      else
        order_items.find_each(&:return_to_stock!)
      end
    end
end
