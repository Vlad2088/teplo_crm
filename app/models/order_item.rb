class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :item, polymorphic: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :stock_available, on: :create, if: -> { product_item? }

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

  # Автосписание товара со склада при создании позиции
  after_create :withdraw_from_stock!, if: :product_item?
  # Возврат товара на склад при удалении позиции
  after_destroy :return_to_stock!, if: :product_item?

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

    def withdraw_from_stock!
      StockMovement.create!(
        product: item,
        order: order,
        movement_type: :out,
        quantity_change: quantity.to_i
      )
    end

    def return_to_stock!
      return unless item

      StockMovement.create!(
        product: item,
        order: order,
        movement_type: :in,
        quantity_change: quantity.to_i
      )
    end
end
