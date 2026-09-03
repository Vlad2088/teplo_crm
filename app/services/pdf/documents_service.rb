require "prawn/table"

# Генерация печатных форм (PDF) для документов заказа:
# смета, акт, счёт на оплату, УПД (договор — следующий этап)
class Pdf::DocumentsService
  FONT_DIR = "/usr/share/fonts/truetype/dejavu".freeze
  VAT_NOTE = "НДС не облагается на основании п. 2 ст. 346.11 НК РФ".freeze

  def initialize(document)
    @document = document
    @order = document.order
    @company = CompanySetting.current
  end

  def render
    case @document.doc_type
    when "estimate" then render_estimate
    when "act" then render_act
    when "invoice" then render_invoice
    when "upd" then render_upd
    when "torg12" then render_torg12
    else render_stub
    end
  end

  private

    attr_reader :document, :order, :company

    def pdf_options
      { page_size: "A4", margin: [ 40, 40, 40, 40 ] }
    end

    def setup_fonts(pdf)
      pdf.font_families.update(
        "DejaVu" => {
          normal: "#{FONT_DIR}/DejaVuSans.ttf",
          bold: "#{FONT_DIR}/DejaVuSans-Bold.ttf"
        }
      )
      pdf.font "DejaVu"
    end

    # Шапка: реквизиты исполнителя слева, тип документа справа
    def draw_header(pdf, doc_title, title_size: 16, box_width: 200, subtitle: nil)
      pdf.bounding_box([ 0, pdf.cursor ], width: 300) do
        pdf.font "DejaVu", size: 10 do
          pdf.text company.name.to_s, size: 12, style: :bold
          company.requisites_lines.each { |line| pdf.text line }
          pdf.text company.phone.to_s if company.phone.present?
        end
      end
      pdf.bounding_box([ pdf.bounds.right - box_width, pdf.cursor ], width: box_width) do
        pdf.font "DejaVu", size: title_size, style: :bold do
          pdf.text doc_title, align: :right
        end
        if subtitle
          pdf.font "DejaVu", size: 9 do
            pdf.text subtitle, align: :right
          end
        end
        pdf.font "DejaVu", size: 10 do
          pdf.text "№ #{doc_number}", align: :right if doc_number.present?
          pdf.text("от #{l(document.document_date || Date.current)}", align: :right) if document.document_date
        end
      end
      pdf.move_down 20
      pdf.stroke_horizontal_rule
      pdf.move_down 16
    end

    # Блок заказчика и объекта — реквизиты по типу клиента
    def draw_customer(pdf)
      client = order.client
      pdf.font "DejaVu", size: 10 do
        pdf.text "<b>Заказчик:</b> #{client&.display_name}", inline_format: true
        client&.requisites_lines&.each { |line| pdf.text line }
        pdf.text "Тел.: #{client.phone}" if client&.phone.present?
        pdf.move_down 6
        pdf.text "<b>Адрес объекта:</b> #{order.address}", inline_format: true
        pdf.move_down 14
      end
    end

    # Таблица позиций (для сметы — все, для акта — только услуги)
    def draw_items_table(pdf, items)
      data = [ [ "№", "Наименование", "Кол-во", "Цена, ₽", "Сумма, ₽" ] ]
      items.each_with_index do |item, i|
        unit = item.product_item? ? item.item.unit.to_s : "м²"
        data << [
          (i + 1).to_s,
          item.item&.name.to_s,
          "#{format_qty(item.quantity)} #{unit}",
          money(item.unit_price),
          money(item.total_price)
        ]
      end

      pdf.table(data, width: pdf.bounds.width, header: true) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "F3F4F6"
        t.columns(0).width = 30
        t.columns(2).width = 80
        t.columns(3).width = 90
        t.columns(4).width = 100
        t.columns(0).align = :center
        t.columns(3..4).align = :right
        t.cells.border_width = 0.5
        t.cells.border_color = "D1D5DB"
        t.cells.padding = [ 6, 8, 6, 8 ]
      end
    end

    # Таблица позиций с графами НДС (УПД, форма 1137)
    def draw_items_table_vat(pdf, items)
      data = [ [ "№", "Наименование", "Кол-во", "Ед.", "Цена, ₽", "Ставка НДС", "Сумма НДС", "Сумма, ₽" ] ]
      items.each_with_index do |item, i|
        unit = item.product_item? ? item.item.unit.to_s : "м²"
        data << [
          (i + 1).to_s,
          item.item&.name.to_s,
          format_qty(item.quantity),
          unit,
          money(item.unit_price),
          "Без НДС",
          "—",
          money(item.total_price)
        ]
      end

      pdf.table(data, width: pdf.bounds.width, header: true) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "F3F4F6"
        t.columns(0).width = 22
        t.columns(2).width = 45
        t.columns(3).width = 38
        t.columns(4).width = 75
        t.columns(5).width = 64
        t.columns(6).width = 64
        t.columns(7).width = 80
        t.columns(0).align = :center
        t.columns(3).align = :center
        t.columns(4..7).align = :right
        t.cells.border_width = 0.5
        t.cells.border_color = "D1D5DB"
        t.cells.padding = [ 6, 6, 6, 6 ]
        t.cells.size = 9
      end
    end

    # Итоги: сумма, скидка, ИТОГО
    def draw_totals(pdf, items)
      items_total = items.sum(&:total_price)
      pdf.move_down 12

      if order.discount_percent.to_d > 0
        discount_amount = items_total * order.discount_percent / 100
        total_due = items_total - discount_amount
        draw_total_row(pdf, "Сумма:", items_total)
        draw_total_row(pdf, "Скидка (#{format_qty(order.discount_percent)}%):", -discount_amount)
        draw_total_row(pdf, "ИТОГО:", total_due, bold: true, size: 13)
      else
        draw_total_row(pdf, "ИТОГО:", items_total, bold: true, size: 13)
      end
    end

    # Итоги для счёта и УПД с отметкой НДС (неплательщик — УСН)
    def draw_totals_with_vat(pdf, items, total_label:)
      items_total = items.sum(&:total_price)
      pdf.move_down 12

      if order.discount_percent.to_d > 0
        discount_amount = items_total * order.discount_percent / 100
        total_due = items_total - discount_amount
        draw_total_row(pdf, "Сумма:", items_total)
        draw_total_row(pdf, "Скидка (#{format_qty(order.discount_percent)}%):", -discount_amount)
        draw_total_row(pdf, total_label, total_due, bold: true, size: 13)
      else
        draw_total_row(pdf, total_label, items_total, bold: true, size: 13)
      end

      draw_total_row(pdf, "НДС:", "не облагается")
      pdf.move_down 2
      pdf.font "DejaVu", size: 8 do
        pdf.text VAT_NOTE, align: :right, color: "6B7280"
      end
    end

    def draw_total_row(pdf, label, value, bold: false, size: 11)
      pdf.font "DejaVu", size: size, style: (bold ? :bold : :normal) do
        pdf.float do
          pdf.text_box label, at: [ pdf.bounds.right - 320, pdf.cursor ], width: 200, align: :right
        end
        pdf.text_box formatted_value(value), at: [ pdf.bounds.right - 110, pdf.cursor ], width: 110, align: :right
        pdf.move_down size + 4
      end
    end

    # Блок реквизитов для оплаты (счёт)
    def draw_payment_details(pdf)
      pdf.move_down 14
      pdf.font "DejaVu", size: 10 do
        pdf.text "<b>Реквизиты для оплаты</b>", inline_format: true
        pdf.move_down 4
        lines = [ "Получатель: #{company.name}" ]
        lines << "ИНН #{company.inn}" if company.inn.present?
        lines << "Р/с #{company.bank_account}" if company.bank_account.present?
        lines << "Банк: #{company.bank_name}" if company.bank_name.present?
        lines << "БИК #{company.bank_bik}" if company.bank_bik.present?
        lines << "К/с #{company.bank_corr_account}" if company.bank_corr_account.present?
        lines.each { |line| pdf.text line }
      end
    end

    # Подписи сторон
    def draw_signatures(pdf, caption_left, caption_right)
      pdf.move_down 40
      pdf.font "DejaVu", size: 10 do
        y = pdf.cursor
        pdf.stroke_horizontal_line 0, 150, at: y - 25
        pdf.stroke_horizontal_line pdf.bounds.right - 150, pdf.bounds.right, at: y - 25
        pdf.draw_text caption_left, at: [ 0, y - 40 ]
        pdf.draw_text caption_right, at: [ pdf.bounds.right - 150, y - 40 ]
        pdf.move_down 55

        # ФИО под подписями
        pdf.draw_text(company.signature_caption.to_s, at: [ 0, pdf.cursor ])
        pdf.draw_text(order.client&.name.to_s, at: [ pdf.bounds.right - 150, pdf.cursor ]) if order.client
      end
    end

    # Подпись только исполнителя (счёт на оплату)
    def draw_single_signature(pdf)
      pdf.move_down 40
      pdf.font "DejaVu", size: 10 do
        y = pdf.cursor
        pdf.stroke_horizontal_line pdf.bounds.right - 150, pdf.bounds.right, at: y - 25
        pdf.draw_text "Исполнитель", at: [ pdf.bounds.right - 150, y - 40 ]
        pdf.move_down 55
        pdf.draw_text(company.signature_caption.to_s, at: [ pdf.bounds.right - 150, pdf.cursor ])
      end
    end

    def l(date)
      I18n.l(date, format: :long)
    end

    def money(value)
      ActionController::Base.helpers.number_to_currency(value, unit: "", precision: 2, delimiter: " ")&.strip + " ₽"
    rescue StandardError
      value.to_s
    end

    def formatted_value(value)
      value.is_a?(String) ? value : money(value)
    end

    def format_qty(value)
      value.to_s.gsub(/\.0$/, "")
    end

    # Номер документа из заголовка («Счёт № 5» → «5»)
    def doc_number
      return "" unless document.title.to_s.include?("№")

      document.title.to_s.gsub(/^.*№\s*/, "").strip
    end

    def number_part
      doc_number.present? ? "№ #{doc_number} " : ""
    end

    def doc_date
      document.document_date || Date.current
    end

    # --- СМЕТА ---
    def render_estimate
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, "СМЕТА")
        draw_customer(pdf)

        items = order.order_items
        if items.any?
          draw_items_table(pdf, items)
          draw_totals(pdf, items)
        else
          pdf.text "Состав заказа пуст", color: "9CA3AF"
        end

        pdf.move_down 10
        pdf.font "DejaVu", size: 9 do
          pdf.text "Смета действительна 14 дней с даты составления.", color: "6B7280"
        end

        draw_signatures(pdf, "Исполнитель", "Заказчик")
      end.render
    end

    # --- АКТ (только услуги, материалы — в УПД) ---
    def render_act
      services = order.order_items.select(&:service_item?)

      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, "АКТ ВЫПОЛНЕННЫХ РАБОТ")
        draw_customer(pdf)

        pdf.font "DejaVu", size: 10 do
          pdf.text "Исполнитель с одной стороны и Заказчик с другой стороны составили настоящий акт о том, " \
                   "что Исполнитель выполнил следующие работы (услуги):"
          pdf.move_down 10
        end

        if services.any?
          draw_items_table(pdf, services)
          draw_totals(pdf, services)
        else
          pdf.text "Работы (услуги) в заказе отсутствуют", color: "9CA3AF"
        end

        pdf.move_down 10
        pdf.font "DejaVu", size: 10 do
          pdf.text "Работы выполнены в полном объёме. Заказчик претензий по объёму, качеству и срокам не имеет."
        end

        draw_signatures(pdf, "Исполнитель", "Заказчик")
      end.render
    end

    # --- СЧЁТ НА ОПЛАТУ ---
    def render_invoice
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, "СЧЁТ НА ОПЛАТУ")
        draw_customer(pdf)

        items = order.order_items
        if items.any?
          draw_items_table(pdf, items)
          draw_totals_with_vat(pdf, items, total_label: "ИТОГО к оплате:")
        else
          pdf.text "Состав заказа пуст", color: "9CA3AF"
        end

        draw_payment_details(pdf)

        pdf.move_down 10
        pdf.font "DejaVu", size: 10 do
          pdf.text "<b>Назначение платежа:</b> Оплата по счёту #{number_part}от #{l(doc_date)}. НДС не облагается.",
                   inline_format: true
        end

        pdf.move_down 6
        pdf.font "DejaVu", size: 9 do
          pdf.text "Счёт действителен до оплаты.", color: "6B7280"
        end

        draw_single_signature(pdf)
      end.render
    end

    # --- УПД (статус 2: первичный учётный документ, без функции счёта-фактуры) ---
    def render_upd
      items = order.order_items

      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, "УНИВЕРСАЛЬНЫЙ ПЕРЕДАТОЧНЫЙ ДОКУМЕНТ",
                    title_size: 12, box_width: 230,
                    subtitle: "Статус: 2 — первичный учётный документ")
        draw_customer(pdf)

        pdf.font "DejaVu", size: 10 do
          pdf.text "Исполнитель передал товары (материалы) и выполнил работы (услуги), " \
                   "а Заказчик принял следующие позиции:"
          pdf.move_down 10
        end

        if items.any?
          draw_items_table_vat(pdf, items)
          draw_totals_with_vat(pdf, items, total_label: "Всего к оплате:")
        else
          pdf.text "Состав заказа пуст", color: "9CA3AF"
        end

        pdf.move_down 10
        pdf.font "DejaVu", size: 10 do
          pdf.text "Документ составлен в статусе «2». Счёт-фактура не выставляется: " \
                   "исполнитель применяет упрощённую систему налогообложения (п. 2 ст. 346.11 НК РФ)."
          pdf.move_down 6
          pdf.text "Все позиции переданы/выполнены в полном объёме. Заказчик претензий по " \
                   "количеству, качеству и срокам не имеет."
        end

        draw_signatures(pdf, "Исполнитель", "Заказчик")
      end.render
    end

    # Заглушка для типов без макета (договор — следующий этап)
    def render_stub
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, document.doc_type.upcase)
        pdf.text "Печатная форма для этого типа документа будет добавлена позже.", color: "9CA3AF"
      end.render
    end

    # --- НАКЛАДНАЯ ТОРГ-12 (унифицированная форма № 0330212, утв. Госкомстатом России 25.12.98 № 132) ---
    # Точная унифицированная форма: шапка с кодами, 15 граф, Итого/Всего по накладной,
    # реквизиты прописью, подписи с подстрочниками, М.П. обеих сторон.
    # Для товаров (материалов); услуги закрываются актом.
    def render_torg12
      items = order.order_items.select(&:product_item?)

      Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: [ 22, 20, 22, 20 ]) do |pdf|
        setup_fonts(pdf)
        pdf.font "DejaVu", size: 7
        full_w = pdf.bounds.width

        # Правый верхний колонтитул формы
        pdf.text "Унифицированная форма № ТОРГ-12", align: :right, size: 7
        pdf.text "Утверждена постановлением Госкомстата России от 25.12.98 № 132", align: :right, size: 6
        pdf.move_down 2

        # Заголовочный блок: реквизиты сторон слева, коды справа
        client_okpo = order.client&.okpo.to_s
        pdf.table([
          [ { content: "<b>Грузоотправитель:</b> #{company_full_requisites}\n(организация-грузоотправитель, адрес, телефон, факс, банковские реквизиты)", inline_format: true },
            { content: "Коды\n\nФорма\nпо ОКУД\n\n0330212", align: :center } ],
          [ { content: "<b>Структурное подразделение:</b> Основной склад", inline_format: true },
            { content: "Вид деятельности\nпо ОКДП\n\n#{company.okved}", align: :center } ],
          [ { content: "<b>Грузополучатель:</b> #{client_full_requisites}\n(организация, адрес, телефон, факс, банковские реквизиты)", inline_format: true },
            { content: "по ОКПО\n\n#{client_okpo}", align: :center } ],
          [ { content: "<b>Поставщик:</b> #{company_full_requisites}\n(организация, адрес, телефон, факс, банковские реквизиты)", inline_format: true },
            { content: "по ОКПО\n\n#{company.okpo}", align: :center } ],
          [ { content: "<b>Плательщик:</b> #{client_full_requisites}\n(организация, адрес, телефон, факс, банковские реквизиты)", inline_format: true },
            { content: "по ОКПО\n\n#{client_okpo}", align: :center } ],
          [ { content: "<b>Основание:</b> #{order_basis}\n(договор, заказ-наряд)", inline_format: true },
            { content: "номер\n\nдата", align: :center } ]
        ], width: full_w, cell_style: { border_width: 0.5, border_color: "000000", size: 6.5, padding: [ 3, 4, 3, 4 ] }) do |t|
          t.column(1).width = 100
        end

        pdf.move_down 6

        # Номер / дата / транспортная накладная + заголовок
        title_w = 160
        rest_w = (full_w - title_w) / 4
        pdf.table([
          [ { content: "ТОВАРНАЯ НАКЛАДНАЯ", rowspan: 2, align: :center, valign: :center, size: 10, font_style: :bold },
            { content: "Номер документа", align: :center },
            { content: "Дата составления", align: :center },
            { content: "Транспортная накладная: номер", align: :center },
            { content: "дата", align: :center } ],
          [ { content: doc_number.presence || "—", align: :center, size: 9, font_style: :bold },
            { content: format_date_torg(doc_date), align: :center, size: 9, font_style: :bold },
            { content: "—" },
            { content: "—" } ]
        ], width: full_w, cell_style: { border_width: 0.5, border_color: "000000", size: 6.5, padding: [ 3, 3, 3, 3 ] }) do |t|
          t.column(0).width = title_w
          t.columns(1..4).width = rest_w
        end

        pdf.move_down 8

        # Табличная часть — 15 граф унифицированной формы (шапка одной строкой, без spans)
        header = [
          "Номер по порядку",
          "Товар: наименование, характеристика, сорт, артикул",
          "Код",
          "Ед. изм.: код по ОКЕИ",
          "Ед. изм.: наиме-нование",
          "Вид упа-ковки",
          "Коли-чество в одном месте",
          "Мест, штук",
          "Мас-са брут-то",
          "Коли-чество (мас-са нет-то)",
          "Цена, руб. коп.",
          "Сумма без учета НДС, руб. коп.",
          "НДС: ставка, %",
          "НДС: сумма, руб. коп.",
          "Сумма с уче-том НДС, руб. коп."
        ]
        data = [ header ]
        items.each_with_index do |item, i|
          product = item.item
          unit = product.unit.to_s
          data << [
            (i + 1).to_s,
            product.name.to_s,
            product.sku.to_s,
            okei_code(unit),
            unit,
            "—",
            "—",
            format_qty(item.quantity),
            "—",
            format_qty(item.quantity),
            money_plain(item.unit_price),
            money_plain(item.total_price),
            "Без НДС",
            "—",
            money_plain(item.total_price)
          ]
        end

        qty_sum = items.sum(&:quantity)
        sum_total = items.sum(&:total_price)
        total_due = order.discount_percent.to_d > 0 ? sum_total * (1 - order.discount_percent / 100) : sum_total
        bold_r = { font_style: :bold, align: :right }
        data << [ { content: "Итого", colspan: 7, **bold_r },
                  format_qty(qty_sum), "Х", format_qty(qty_sum), "Х",
                  { content: money_plain(sum_total), **bold_r }, "Х", "Х",
                  { content: money_plain(sum_total), **bold_r } ]
        data << [ { content: "Всего по накладной", colspan: 7, **bold_r },
                  format_qty(qty_sum), "Х", format_qty(qty_sum), "Х",
                  { content: money_plain(sum_total), **bold_r }, "Х", "Х",
                  { content: money_plain(sum_total), **bold_r } ]

        col_widths = [ 24, 90, 38, 26, 28, 24, 26, 26, 24, 28, 42, 50, 28, 28, 50 ]
        scale = full_w.to_f / col_widths.sum
        col_widths = col_widths.map { |w| w * scale }
        pdf.table(data, width: full_w, cell_style: { border_width: 0.5, border_color: "000000", size: 7, padding: [ 2, 2, 2, 2 ] }) do |t|
          t.row(0).font_style = :bold
          t.row(0).size = 6
          col_widths.each_with_index { |w, ci| t.column(ci).width = w }
          t.columns(0).align = :center
          t.columns(2..14).align = :right
          t.columns(3..8).align = :center
        end

        # Подтабличный блок: приложение, записей прописью, массы, доверенность, сумма прописью
        pdf.move_down 6
        pdf.font "DejaVu", size: 7 do
          count_words = triple_in_words(items.size, false).capitalize
          pdf.text "Товарная накладная имеет приложение на ______ листах"
          pdf.text "и содержит #{count_words} порядковых номеров записей"
          pdf.text "Всего мест ________________            Масса груза (нетто) ________________"
          pdf.text "Масса груза (брутто) ________________"
          pdf.text "Приложение (паспорта, сертификаты и т.п.) на ______ листах            По доверенности № ________ от ______________"
          pdf.move_down 4
          pdf.text "Всего отпущено на сумму <b>#{amount_in_words(total_due)}</b>", inline_format: true, size: 8
          if order.discount_percent.to_d > 0
            pdf.text "Сумма по позициям: #{money(sum_total)}; скидка #{format_qty(order.discount_percent)}% учтена в итоговой сумме.", size: 6.5
          end
          pdf.text "НДС: Без НДС (п. 2 ст. 346.11 НК РФ)", size: 6.5
        end

        # Подписи: должность / подпись / расшифровка + М.П.
        pdf.move_down 18
        pos = company.position_title.to_s
        ini = signature_initials
        cli_name = order.client&.display_name.to_s
        sign_widths = [ 85, 100, 55, 80, 90, 55, 80 ]
        sign_scale = full_w.to_f / sign_widths.sum
        sign_widths = sign_widths.map { |w| w * sign_scale }
        pdf.table([
          [ { content: "Отпуск груза разрешил" }, { content: pos }, { content: "" }, { content: ini },
            { content: "Главный (старший) бухгалтер" }, { content: "" }, { content: ini } ],
          [ { content: "(должность)", size: 5, border_width: 0 }, { content: "(подпись)", size: 5, border_width: 0 },
            { content: "(подпись)", size: 5, border_width: 0 }, { content: "(расшифровка подписи)", size: 5, border_width: 0 },
            { content: "", size: 5, border_width: 0 }, { content: "(подпись)", size: 5, border_width: 0 },
            { content: "(расшифровка подписи)", size: 5, border_width: 0 } ],
          [ { content: "Отпуск груза произвел" }, { content: pos }, { content: "" }, { content: ini },
            { content: "Груз принял" }, { content: "" }, { content: "" } ],
          [ { content: "(должность)", size: 5, border_width: 0 }, { content: "(подпись)", size: 5, border_width: 0 },
            { content: "(подпись)", size: 5, border_width: 0 }, { content: "(расшифровка подписи)", size: 5, border_width: 0 },
            { content: "(должность)", size: 5, border_width: 0 }, { content: "(подпись)", size: 5, border_width: 0 },
            { content: "(расшифровка подписи)", size: 5, border_width: 0 } ],
          [ { content: "Груз получил грузополучатель" }, { content: "" }, { content: "" }, { content: cli_name },
            { content: "" }, { content: "" }, { content: "" } ]
        ], width: full_w, cell_style: { border_width: 0.5, border_color: "000000", size: 7, padding: [ 4, 3, 4, 3 ] }) do |t|
          sign_widths.each_with_index { |w, ci| t.column(ci).width = w }
        end

        pdf.move_down 10
        pdf.font "DejaVu", size: 7 do
          pdf.draw_text "М.П.  \"#{doc_date.day}\" #{month_genitive(doc_date.month)} #{doc_date.year} года", at: [ 0, pdf.cursor ]
          pdf.draw_text "М.П.  \"____\" ______________ 20____ года", at: [ pdf.bounds.right - 190, pdf.cursor ]
        end
      end.render
    end

    # Сумма без знака валюты (для табличных граф ТОРГ-12)
    def money_plain(value)
      ActionController::Base.helpers.number_to_currency(value, unit: "", precision: 2, delimiter: " ")&.strip
    rescue StandardError
      value.to_s
    end

    # Расшифровка подписи: «Ганиев В. Р.» из полного ФИО
    def signature_initials
      source = company.director_name.presence || company.name
      parts = source.to_s.split
      return company.short_name.to_s if parts.size < 2

      "#{parts[0]} #{parts[1..].map { |p| "#{p[0]}." }.join(' ')}"
    end

    # Полные реквизиты компании одной строкой (для ТОРГ-12)
    def company_full_requisites
      parts = [ company.name, "ИНН #{company.inn}" ]
      parts << company.address if company.address.present?
      parts << "тел.: #{company.phone}" if company.phone.present?
      parts << "р/с #{company.bank_account}" if company.bank_account.present?
      parts << "в банке #{company.bank_name}" if company.bank_name.present?
      parts << "БИК #{company.bank_bik}" if company.bank_bik.present?
      parts << "к/с #{company.bank_corr_account}" if company.bank_corr_account.present?
      parts.join(", ")
    end

    # Полные реквизиты клиента одной строкой
    def client_full_requisites
      client = order.client
      return "" unless client

      parts = [ client.display_name ]
      parts << "ИНН #{client.inn}" if client.inn.present?
      addr = client.registration_address.presence || client.address.presence
      parts << addr if addr
      parts << "тел.: #{client.phone}" if client.phone.present?
      parts << "р/с #{client.bank_account}" if client.bank_account.present?
      parts << "в банке #{client.bank_name}" if client.bank_name.present?
      parts << "БИК #{client.bank_bik}" if client.bank_bik.present?
      parts << "к/с #{client.bank_corr_account}" if client.bank_corr_account.present?
      parts.compact.join(", ")
    end

    # Основание (договор/заказ)
    def order_basis
      "Заказ \u2116#{order.id} от #{format_date_torg(order.created_at.to_date)}"
    end

    # Код ОКЕИ по единице измерения
    def okei_code(unit)
      { "шт" => "796", "\u043c\u00b2" => "055", "м" => "006", "м.кв." => "055" }.fetch(unit, "")
    end

    # Дата в формате ТОРГ-12 (05.06.2026)
    def format_date_torg(date)
      date.strftime("%d.%m.%Y")
    end

    # Название месяца в родительном падеже
    def month_genitive(month)
      %w[января февраля марта апреля мая июня июля августа сентября октября ноября декабря][month - 1]
    end

    # Сумма прописью: рубли и копейки
    def amount_in_words(value)
      rubles = value.to_i
      kopecks = ((value - rubles) * 100).round
      rub_words = amount_rubles_in_words(rubles)
      kop_words = kopecks == 1 ? "копейка" : [ 2, 3, 4 ].include?(kopecks % 10) && ![ 12, 13, 14 ].include?(kopecks % 100) ? "копейки" : "копеек"
      "#{rub_words} #{kopecks} #{kop_words}"
    end

    RUB_ONES = %w[ноль один два три четыре пять шесть семь восемь девять].freeze
    RUB_ONES_F = %w[ноль одна две три четыре пять шесть семь восемь девять].freeze
    RUB_TEENS = %w[десять одиннадцать двенадцать тринадцать четырнадцать пятнадцать шестнадцать семнадцать восемнадцать девятнадцать].freeze
    RUB_TENS = %w[x десять двадцать тридцать сорок пятьдесят шестьдесят семьдесят восемьдесят девяносто].freeze
    RUB_HUNDREDS = %w[x сто двести триста четыреста пятьсот шестьсот семьсот восемьсот девятьсот].freeze

    def amount_rubles_in_words(rubles)
      return "Ноль рублей" if rubles.zero?

      parts = []
      rest = rubles
      [ [ 1_000_000, "миллион", "миллиона", "миллионов" ], [ 1000, "тысяча", "тысячи", "тысяч" ] ].each do |base, one, few, many|
        n = rest / base
        next if n.zero?

        rest -= n * base
        parts << triple_in_words(n, base == 1000)
        parts << plural_form(n, one, few, many)
      end
      parts << triple_in_words(rest, false) if rest.positive?
      parts << plural_form(rubles, "рубль", "рубля", "рублей")
      parts.join(" ").capitalize
    end

    def triple_in_words(n, female)
      parts = []
      parts << RUB_HUNDREDS[n / 100] if n >= 100
      tt = n % 100
      if tt >= 10 && tt < 20
        parts << RUB_TEENS[tt - 10]
      else
        parts << RUB_TENS[tt / 10] if tt >= 20
        o = tt % 10
        parts << (female ? RUB_ONES_F[o] : RUB_ONES[o]) if o.positive?
      end
      parts.join(" ")
    end

    def plural_form(n, one, few, many)
      n100 = n % 100
      n10 = n % 10
      if n100.between?(11, 14) then many
      elsif n10 == 1 then one
      elsif n10.between?(2, 4) then few
      else many
      end
    end
end
