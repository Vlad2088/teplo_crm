class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :item, polymorphic: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # Контроль остатка — только в «реальных» статусах заказа (черновики склад не трогают)
  validate :stock_available, on: :create, if: -> { product_item? && order.stock_controlled? }

  # Цена за единицу из справочника (товар или услуга)
  def catalog_price
    return item.sale_price.to_d if product_item?
    return item.price_per_sqm.to_d if service_item?

    nil
  end

  def product_item?
    item_type == "Product"
  end

  def service_item?
    item_type == "Service"
  end

  # Пересчёт итога перед сохранением: quantity × unit_price
  before_validation :recalculate_total

  # Складом управляет СТАТУС заказа: черновики (лид/замер/смета) при добавлении позиции
  # ничего не списывают; при входе заказа в «реальный» статус всё списывается разом
  # (Order#sync_stock_with_status). Позиция, добавленная в «реальном» статусе,
  # списывается сразу.
  after_create :withdraw_from_stock!, if: -> { product_item? && order.stock_controlled? }
  # Удаление позиции возвращает товар, только если он был списан
  after_destroy :return_to_stock!, if: :stock_withdrawn?

  # Списать позицию со склада (идемпотентно: один раз)
  def withdraw_from_stock!
    return unless product_item? && item && !stock_withdrawn?

    StockMovement.create!(product: item, order: order, movement_type: :out, quantity_change: quantity.to_i)
    update_column(:stock_withdrawn, true)
  end

  # Вернуть позицию на склад (идемпотентно)
  def return_to_stock!
    return unless product_item? && item && stock_withdrawn?

    StockMovement.create!(product: item, order: order, movement_type: :in, quantity_change: quantity.to_i)
    update_column(:stock_withdrawn, false)
  end

  private

    def recalculate_total
      self.total_price = quantity.to_d * unit_price.to_d if quantity && unit_price
    end

    def stock_available
      return unless item

      needed = quantity.to_i
      available = item.stock_quantity
      return if available >= needed

      errors.add(:quantity, "— недостаточно на складе (доступно #{available}, нужно #{needed})")
    end
end
