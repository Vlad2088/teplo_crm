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
