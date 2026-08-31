module ApplicationHelper
  def sidebar_link(label, path)
    is_active = request.path == path || request.path.start_with?("#{path}/")
    base_class = "block px-4 py-2 rounded-md text-sm font-medium transition"
    if is_active
      link_to label, path, class: "#{base_class} bg-orange-100 text-orange-700"
    else
      link_to label, path, class: "#{base_class} text-gray-700 hover:bg-gray-100"
    end
  end

  ORDER_STATUS_NAMES = {
    "lead" => "Лид",
    "measurement" => "Замер",
    "estimate" => "Смета",
    "contract_signed" => "Договор подписан",
    "materials_paid" => "Материалы оплачены",
    "installation" => "Монтаж",
    "act_signed" => "Акт подписан",
    "installation_paid" => "Монтаж оплачен",
    "completed" => "Завершён",
    "cancelled" => "Отменён"
  }.freeze

  DOC_TYPE_NAMES = {
    "estimate" => "Смета",
    "invoice" => "Счет",
    "act" => "Акт",
    "contract" => "Договор",
    "upd" => "УПД"
  }.freeze

  PAYMENT_TYPE_NAMES = {
    "cash" => "Наличные",
    "cashless" => "Безналичные"
  }.freeze

  # Хелпер для отображения статуса заказа с цветом
  def order_status_badge(status)
    colors = {
      "lead" => "bg-gray-200 text-gray-700",
      "measurement" => "bg-blue-100 text-blue-700",
      "estimate" => "bg-indigo-100 text-indigo-700",
      "contract_signed" => "bg-green-100 text-green-700",
      "materials_paid" => "bg-teal-100 text-teal-700",
      "installation" => "bg-yellow-100 text-yellow-700",
      "act_signed" => "bg-lime-100 text-lime-700",
      "installation_paid" => "bg-emerald-100 text-emerald-700",
      "completed" => "bg-green-200 text-green-800",
      "cancelled" => "bg-red-100 text-red-700"
    }
    tag.span ORDER_STATUS_NAMES[status] || status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full #{colors[status] || 'bg-gray-100 text-gray-600'}"
  end

  # Русские названия статусов заказа для формы
  def order_status_options
    Order.statuses.keys.map { |s| [ ORDER_STATUS_NAMES[s] || s.humanize, s ] }
  end

  # Отображение типа клиента
  def client_type_badge(client_type)
    names = { "individual" => "Физ. лицо", "entrepreneur" => "ИП", "legal_entity" => "Юр. лицо" }
    colors = { "individual" => "bg-purple-100 text-purple-700", "entrepreneur" => "bg-orange-100 text-orange-700", "legal_entity" => "bg-cyan-100 text-cyan-700" }
    tag.span names[client_type] || client_type, class: "px-2 py-1 text-xs font-medium rounded-full #{colors[client_type] || 'bg-gray-100 text-gray-600'}"
  end

  # Форматирование денежных сумм
  def format_currency(amount)
    return "—" if amount.nil?
    number_to_currency(amount, unit: "₽", precision: 2, delimiter: " ")
  end

  # Форматирование площади
  def format_area(value)
    return "—" if value.nil?
    "#{value} м²"
  end

  # Бадж категории товара
  def product_category_badge(category)
    names = { "warm_floor" => "Тёплый пол", "thermostat" => "Терморегулятор", "underlay" => "Подложка", "other" => "Прочее" }
    colors = { "warm_floor" => "bg-red-100 text-red-700", "thermostat" => "bg-blue-100 text-blue-700", "underlay" => "bg-green-100 text-green-700", "other" => "bg-gray-100 text-gray-600" }
    tag.span names[category] || category.humanize, class: "px-2 py-1 text-xs font-medium rounded-full #{colors[category] || 'bg-gray-100 text-gray-600'}"
  end

  # Бадж бренда
  def product_brand_badge(brand)
    names = { "tesla" => "Tesla", "xl_pipe" => "XL Pipe", "other_brand" => "Другое" }
    colors = { "tesla" => "bg-yellow-100 text-yellow-700", "xl_pipe" => "bg-indigo-100 text-indigo-700", "other_brand" => "bg-gray-100 text-gray-600" }
    tag.span names[brand] || brand.humanize, class: "px-2 py-1 text-xs font-medium rounded-full #{colors[brand] || 'bg-gray-100 text-gray-600'}"
  end

  # Бадж типа движения склада
  def movement_type_badge(movement_type)
    names = { "in" => "Поступление", "out" => "Списание" }
    colors = { "in" => "bg-green-100 text-green-700", "out" => "bg-red-100 text-red-700" }
    tag.span names[movement_type] || movement_type.humanize, class: "px-2 py-1 text-xs font-medium rounded-full #{colors[movement_type] || 'bg-gray-100 text-gray-600'}"
  end

  # Русские названия типов документов для формы
  def doc_type_options
    Document.doc_types.keys.map { |d| [ DOC_TYPE_NAMES[d] || d.humanize, d ] }
  end

  # Русские названия типов оплаты для формы
  def payment_type_options
    Payment.payment_types.keys.map { |p| [ PAYMENT_TYPE_NAMES[p] || p.humanize, p ] }
  end

  # Заголовок формы (общий компонент)
  def form_section(title, &block)
    content = capture(&block)
    tag.div(class: "bg-white rounded-lg shadow-sm border border-gray-200 p-5 mb-5") do
      tag.h3(title, class: "text-lg font-semibold text-gray-800 mb-4 pb-2 border-b border-gray-100") +
      content
    end
  end

  # Поле формы с подписью
  def field_wrapper(form, attribute, label, &block)
    content = capture(&block)
    tag.div(class: "mb-4") do
      form.label(attribute, label, class: "block text-sm font-medium text-gray-700 mb-1") +
      content +
      (attribute_error(form.object, attribute) || "")
    end
  end

  private

  def attribute_error(object, attribute)
    return nil unless object.errors[attribute].any?
    tag.p(object.errors.full_messages_for(attribute).join(", "), class: "mt-1 text-sm text-red-600")
  end
end
