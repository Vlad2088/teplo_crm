import { Controller } from "@hotwired/stimulus"

// Живой пересчёт позиции и итогов в карточке заказа
export default class extends Controller {
  static targets = [
    "itemForm", "toggleBtn", "paymentForm", "documentForm",
    "itemType", "itemId", "quantity", "unitPrice", "itemTotal",
    "itemsTotal", "discountAmount", "totalDue"
  ]

  // каталог: { "Product": { id: { price, unit, stock } }, "Service": { id: { price } } }
  // передаётся через data-sale-summary-catalog-value
  static values = { catalog: Object }

  connect() {
    this.recalc()
  }

  toggleForm() {
    this.itemFormTarget.classList.toggle("hidden")
    this.toggleBtnTarget.classList.toggle("hidden")
  }

  togglePaymentForm() {
    this.paymentFormTarget.classList.toggle("hidden")
  }

  toggleDocumentForm() {
    this.documentFormTarget.classList.toggle("hidden")
  }

  itemTypeChanged() {
    const type = this.itemTypeTarget.value
    const select = this.itemIdTarget
    const items = (this.catalogValue[type] || {})

    // перезаполняем select позициями выбранного типа
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = type === "Service" ? "Выберите услугу..." : "Выберите товар..."
    select.innerHTML = ""
    select.appendChild(blank)

    for (const [id, info] of Object.entries(items)) {
      const opt = document.createElement("option")
      opt.value = id
      const stockNote = info.stock !== undefined ? ` (ост. ${info.stock} ${info.unit || ""})` : ""
      opt.textContent = `${info.name}${stockNote}`
      select.appendChild(opt)
    }

    this.clearPrice()
  }

  itemSelected() {
    const type = this.itemTypeTarget.value
    const id = this.itemIdTarget.value
    const info = (this.catalogValue[type] || {})[id]
    if (!info) return

    this.unitPriceTarget.value = info.price
    this.recalc()
  }

  clearPrice() {
    this.unitPriceTarget.value = ""
    this.recalc()
  }

  // пересчёт итогов при изменении скидки (до сохранения — мгновенный отклик)
  applyDiscount() {
    this.recalcTotals()
  }

  recalcTotals() {
    const itemsTotal = this.parseServerMoney(this.itemsTotalTarget?.textContent)
    if (!this.hasItemsTotalTarget || itemsTotal === 0) return

    const discountInput = this.element.querySelector("input[name=\"order[discount_percent]\"]")
    const discount = Math.min(100, Math.max(0, this.parseNum(discountInput?.value)))
    const discountAmount = itemsTotal * discount / 100
    const totalDue = itemsTotal - discountAmount

    if (this.hasDiscountAmountTarget) {
      this.discountAmountTarget.textContent = "− " + this.formatMoney(discountAmount)
    }
    if (this.hasTotalDueTarget) {
      this.totalDueTarget.textContent = this.formatMoney(totalDue)
    }
  }

  // "29 000 ₽" -> 29000
  parseServerMoney(text) {
    if (!text) return 0
    const cleaned = String(text).replace(/[^\d.,-]/g, "").replace(",", ".")
    const parsed = parseFloat(cleaned)
    return isNaN(parsed) ? 0 : parsed
  }

  recalc() {
    const qty = this.parseNum(this.quantityTarget?.value)
    const price = this.parseNum(this.unitPriceTarget?.value)

    if (this.hasItemTotalTarget) {
      const sum = qty * price
      this.itemTotalTarget.textContent = this.formatMoney(sum)
    }
  }

  parseNum(value) {
    if (!value) return 0
    const normalized = String(value).replace(",", ".").replace(/\s/g, "")
    const parsed = parseFloat(normalized)
    return isNaN(parsed) ? 0 : parsed
  }

  formatMoney(amount) {
    const formatted = new Intl.NumberFormat("ru-RU", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    }).format(amount)
    return `${formatted} ₽`
  }
}
