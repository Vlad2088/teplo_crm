import { Controller } from "@hotwired/stimulus"

// Реквизиты компании: показывает поля по статусу (ИП / юрлицо)
export default class extends Controller {
  static targets = [ "typeSelect", "innFields" ]

  connect() {
    this.typeChanged()
  }

  typeChanged() {
    const isLegal = this.typeSelectTarget.value === "legal_entity"

    const innLabel = this.element.querySelector('label[for="company_setting_inn"]')
    if (innLabel) innLabel.textContent = isLegal ? "ИНН (10 цифр) *" : "ИНН (12 цифр) *"

    const ogrnLabel = this.element.querySelector('label[for="company_setting_ogrn"]')
    if (ogrnLabel) ogrnLabel.textContent = isLegal ? "ОГРН (13 цифр)" : "ОГРНИП (15 цифр)"

    // КПП и сокращённое наименование — только для юрлица
    const kpp = this.element.querySelector('[data-company-type-block="kpp"]')
    if (kpp) kpp.classList.toggle("hidden", !isLegal)
    const shortName = this.element.querySelector('[data-company-type-block="short_name"]')
    if (shortName) shortName.classList.toggle("hidden", !isLegal)
    const position = this.element.querySelector('[data-company-type-block="position"]')
    if (position) {
      position.classList.toggle("hidden", !isLegal)
      const input = position.querySelector("input")
      if (input) input.disabled = !isLegal
    }
  }
}
