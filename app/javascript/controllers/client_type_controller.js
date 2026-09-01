import { Controller } from "@hotwired/stimulus"

// Показывает/скрывает группы полей по типу клиента.
// Подписи ИНН/ОГРН обновляет под выбранный тип.
export default class extends Controller {
  static targets = [ "typeSelect", "individualFields", "entrepreneurFields",
                     "legalEntityFields", "bankFields" ]

  connect() {
    this.typeChanged()
  }

  typeChanged() {
    const type = this.typeSelectTarget.value

    this.toggle(this.individualFieldsTarget, type === "individual")
    this.toggle(this.entrepreneurFieldsTarget, type === "entrepreneur" || type === "legal_entity")
    this.toggle(this.legalEntityFieldsTarget, type === "legal_entity")
    this.toggle(this.bankFieldsTarget, type === "entrepreneur" || type === "legal_entity")

    // подписи под тип: ИНН 12/10 цифр, ОГРНИП/ОГРН
    const innLabel = this.element.querySelector('label[for="client_inn"]')
    if (innLabel) innLabel.textContent = type === "legal_entity" ? "ИНН (10 цифр)" : "ИНН (12 цифр)"
    const ogrnLabel = this.element.querySelector('label[for="client_ogrn"]')
    if (ogrnLabel) ogrnLabel.textContent = type === "legal_entity" ? "ОГРН (13 цифр)" : "ОГРНИП (15 цифр)"
  }

  toggle(el, visible) {
    if (!el) return
    el.classList.toggle("hidden", !visible)
    // скрытые поля не отправляются на сервер
    el.querySelectorAll("input, select, textarea").forEach(field => {
      field.disabled = !visible
    })
  }
}
