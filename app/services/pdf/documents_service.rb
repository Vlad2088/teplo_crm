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
    when "contract_work" then render_contract_work
    when "contract_supply" then render_contract_supply
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
          pdf.text "Приложение (паспорта, сертификаты и т.п.) на ______ листах"
          pdf.move_down 4
          pdf.text "Всего отпущено на сумму <b>#{amount_in_words(total_due)}</b>", inline_format: true, size: 8
          if order.discount_percent.to_d > 0
            pdf.text "Сумма по позициям: #{money(sum_total)}; скидка #{format_qty(order.discount_percent)}% учтена в итоговой сумме.", size: 6.5
          end
          pdf.text "НДС: Без НДС (п. 2 ст. 346.11 НК РФ)", size: 6.5
        end

        # Подписи: два блока без рамок — слева грузоотправитель, справа грузополучатель
        pdf.move_down 22
        pos = company.position_title.to_s
        ini = signature_initials
        left_w = (full_w * 0.55).round
        right_x = left_w + 24
        right_w = full_w - right_x
        top_y = pdf.cursor

        pdf.font "DejaVu", size: 7 do
          # Левый блок — грузоотправитель
          pdf.bounding_box([ 0, top_y ], width: left_w) do
            torg_sign_line(pdf, "Отпуск груза разрешил", pos, ini,
                           pos_x: 118, line_from: 245, line_to: 330, name_x: 338)
            pdf.move_down 18
            torg_sign_line(pdf, "Главный (старший) бухгалтер", "", ini,
                           pos_x: 118, line_from: 245, line_to: 330, name_x: 338, position_caption: false)
            pdf.move_down 18
            torg_sign_line(pdf, "Отпуск груза произвел", pos, ini,
                           pos_x: 118, line_from: 245, line_to: 330, name_x: 338)
            pdf.move_down 26
            pdf.draw_text "М.П.", at: [ 0, pdf.cursor ]
            pdf.draw_text "\"#{doc_date.day}\" #{month_genitive(doc_date.month)} #{doc_date.year} года", at: [ 45, pdf.cursor ]
          end

          # Правый блок — грузополучатель (клиент)
          pdf.bounding_box([ right_x, top_y ], width: right_w) do
            torg_sign_line(pdf, "Груз принял", "", "",
                           pos_x: 150, line_from: 150, line_to: 235, name_x: 243, position_caption: false)
            pdf.move_down 18
            torg_sign_line(pdf, "Груз получил грузополучатель", "", "",
                           pos_x: 150, line_from: 150, line_to: 235, name_x: 243, position_caption: false)
            pdf.move_down 32
            pdf.draw_text "По доверенности № ________ от ______________", at: [ 0, pdf.cursor ]
            pdf.move_down 12
            pdf.draw_text "М.П.", at: [ 0, pdf.cursor ]
            pdf.draw_text "\"____\" ______________ 20____ года", at: [ 45, pdf.cursor ]
          end
        end
      end.render
    end


    # --- ДОГОВОР ПОДРЯДА (на выполнение работ по монтажу системы «Тёплый пол») ---
    def render_contract_work
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        pdf.font "DejaVu", size: 10

        # Шапка: номер и город/дата
        pdf.text "ДОГОВОР ПОДРЯДА № #{doc_number}", align: :center, size: 13, style: :bold
        pdf.move_down 2
        pdf.text "на выполнение работ по монтажу системы «Тёплый пол»", align: :center, size: 11
        pdf.move_down 8
        pdf.font "DejaVu", size: 9 do
          pdf.text "г. Петропавловск-Камчатский#{' ' * 40}#{l(doc_date)} г.", align: :center
        end
        pdf.move_down 10

        # Преамбула
        client = order.client
        pdf.font "DejaVu", size: 9 do
          pdf.text "#{company.position_title} #{company.director_name.presence || company.name}, " \
                   "именуемый в дальнейшем «Подрядчик», с одной стороны и " \
                   "#{client_preamble_name}, именуемый в дальнейшем «Заказчик», с другой стороны, " \
                   "вместе именуемые «Стороны», заключили настоящий Договор о нижеследующем:", align: :justify
        end
        pdf.move_down 8

        # Разделы
        sections = contract_work_sections
        sections.each do |title, items|
          pdf.font "DejaVu", size: 10, style: :bold do
            pdf.text title
          end
          pdf.move_down 3
          pdf.font "DejaVu", size: 9 do
            items.each do |item|
              pdf.text item, align: :justify
              pdf.move_down 2
            end
          end
          pdf.move_down 6
        end

        # Реквизиты и подписи двумя столбцами
        pdf.move_down 10
        left_w = pdf.bounds.width / 2 - 10
        top_y = pdf.cursor
        pdf.font "DejaVu", size: 8.5 do
          pdf.bounding_box([ 0, top_y ], width: left_w) do
            pdf.text "ПОДРЯДЧИК", style: :bold
            company.requisites_lines.each { |line| pdf.text line }
            pdf.text "Тел.: #{company.phone}" if company.phone.present?
            pdf.move_down 24
            pdf.text "__________________/ #{signature_initials} /"
          end
          pdf.bounding_box([ pdf.bounds.width / 2 + 10, top_y ], width: left_w) do
            pdf.text "ЗАКАЗЧИК", style: :bold
            pdf.text client&.display_name.to_s
            client&.requisites_lines&.each { |line| pdf.text line }
            pdf.text "Тел.: #{client.phone}" if client&.phone.present?
            pdf.move_down 24
            pdf.text "__________________/ #{client&.short_name.presence || client&.name} /"
          end
        end
      end.render
    end

    # Преамбула: полное имя заказчика по типу
    def client_preamble_name
      client = order.client
      return "" unless client

      if client.individual?
        parts = [ "Гражданин(ка) РФ #{client.name}" ]
        parts << "Паспорт: #{client.passport_series} #{client.passport_number} выдан #{l(client.passport_issued_on)} #{client.passport_issued_by}" if client.passport_number.present?
        parts << "Адрес: #{client.registration_address}" if client.registration_address.present?
        parts.join(". ")
      else
        "#{client.name}#{client.inn.present? ? ", ИНН #{client.inn}" : ""}#{client.address.present? ? ", #{client.address}" : ""}"
      end
    end

    # Приложение-акт: номер и дата существующего акта в заказе, либо пустые поля
    def act_appendix_line
      act = order.documents.find { |d| d.doc_type == "act" }
      if act
        num = act.title.to_s.include?("№") ? act.title : "Акт выполненных работ № #{act.title}"
        "Акт выполненных работ (Приложение № 1): #{num} от #{l(act.document_date || act.created_at.to_date)}"
      else
        "Акт выполненных работ (Приложение № 1) № " + ("_" * 12) + " от " + ("_" * 14)
      end
    end

    # Разделы договора подряда (текст из шаблона пользователя, Подрядчик унифицирован)
    def contract_work_sections
      [
        [ "1. ПРЕДМЕТ ДОГОВОРА", [
          "1.1. Заказчик поручает, а Подрядчик принимает на себя обязательства по выполнению работ по монтажу системы «Тёплый пол» (водяного / электрического) на Объекте, расположенном по адресу: #{order.address.presence || ('_' * 40)}.",
          "1.2. Конкретный перечень, объём и стоимость выполняемых работ, а также перечень и стоимость используемых Подрядчиком материалов (при наличии) определяются в Акте выполненных работ (Приложение № 1 к настоящему Договору), который является неотъемлемой частью настоящего Договора.",
          "1.3. Заказчик обязуется создать Подрядчику необходимые для выполнения работ условия, принять их результат и уплатить обусловленную Договором цену."
        ] ],
        [ "2. СРОКИ ВЫПОЛНЕНИЯ РАБОТ", [
          "2.1. Срок начала выполнения работ: " + "_" * 32 + " г.",
          "2.2. Планируемый срок окончания работ: " + "_" * 32 + " г.",
          "2.3. Сроки могут быть продлены по соглашению Сторон в случае возникновения форс-мажорных обстоятельств, непредоставления Заказчиком доступа к Объекту, задержки поставки материалов Заказчиком или проведения Заказчиком сопутствующих строительных работ."
        ] ],
        [ "3. СТОИМОСТЬ РАБОТ И ПОРЯДОК РАСЧЕТОВ", [
          "3.1. Общая стоимость работ и материалов определяется по факту выполнения и фиксируется в Акте выполненных работ.",
          "3.2. Выплата аванса не предусматривается. Оплата выполненных работ производится Заказчиком в размере 100% (сто процентов) от суммы, указанной в Акте выполненных работ, в течение 2 календарных дней с момента подписания Сторонами Акта выполненных работ.",
          "3.3. Оплата производится путем передачи наличных денежных средств или переводом на банковский счет Подрядчика."
        ] ],
        [ "4. ПРАВА И ОБЯЗАННОСТИ СТОРОН", [
          "4.1. Подрядчик обязуется:",
          "— выполнить работы качественно, в соответствии с технологическими требованиями и правилами монтажа систем тёплого пола;",
          "— перед укладкой финишного покрытия / заливкой стяжки провести гидравлические или электрические испытания (опрессовку / замер сопротивления) системы;",
          "— бережно относиться к имуществу Заказчика, соблюдать чистоту на рабочем месте;",
          "— уведомить Заказчика о непригодности или некачественности предоставленных Заказчиком материалов (если материалы предоставляются Заказчиком).",
          "4.2. Заказчик обязуется:",
          "— обеспечить Подрядчику беспрепятственный доступ к Объекту, а также подключение к источникам электроэнергии и водоснабжения;",
          "— обеспечить подготовку помещения (освободить от строительного мусора, мебели и посторонних предметов) к моменту начала монтажа;",
          "— своевременно принять и оплатить выполненные Подрядчиком работы."
        ] ],
        [ "5. ПОРЯДОК СДАЧИ И ПРИЕМКИ РАБОТ", [
          "5.1. По завершении работ Подрядчик предъявляет результат Заказчику и предоставляет для подписания Акт выполненных работ.",
          "5.2. Заказчик обязуется с участием Подрядчика осмотреть и принять выполненную работу (ее результат) в день завершения монтажа.",
          "5.3. При отсутствии претензий Заказчик подписывает Акт выполненных работ. При наличии замечаний в Акт вносится соответствующая запись с указанием сроков их устранения Подрядчиком."
        ] ],
        [ "6. ГАРАНТИЙНЫЕ ОБЯЗАТЕЛЬСТВА", [
          "6.1. Гарантийный срок на выполненные монтажные работы составляет 10 (десять) лет с даты подписания Акта выполненных работ.",
          "6.2. Гарантия распространяется исключительно на качество монтажных работ. Гарантия на используемые оборудование и материалы предоставляется их заводом-изготовителем.",
          "6.3. Гарантия не распространяется на случаи:",
          "— механического повреждения элементов системы третьими лицами после сдачи работ (при заливке стяжки, укладке плитки, сверлении полов и т.д.);",
          "— нарушения Заказчиком правил эксплуатации системы (перегрев, запуск без полного высыхания стяжки, скачки напряжения и т.д.);",
          "— использования некачественных материалов, предоставленных Заказчиком."
        ] ],
        [ "7. ОТВЕТСТВЕННОСТЬ СТОРОН И РАЗРЕШЕНИЕ СПОРОВ", [
          "7.1. За неисполнение или ненадлежащее исполнение обязательств по настоящему Договору Стороны несут ответственность в соответствии с действующим законодательством РФ.",
          "7.2. Все споры и разногласия решаются путем переговоров. В случае невозможности достижения согласия — в судебном порядке."
        ] ],
        [ "8. РЕКВИЗИТЫ И ПОДПИСИ СТОРОН", [] ]
      ]
    end

    # --- ДОГОВОР ПОСТАВКИ ОБОРУДОВАНИЯ ---
    def render_contract_supply
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        pdf.font "DejaVu", size: 10

        client = order.client

        pdf.text "Договор поставки оборудования № #{doc_number}", align: :center, size: 12, style: :bold
        pdf.move_down 8
        pdf.font "DejaVu", size: 9 do
          pdf.text "г. Петропавловск-Камчатский#{' ' * 40}#{l(doc_date)} г.", align: :center
        end
        pdf.move_down 10

        # Преамбула: покупатель (полные данные по типу) + поставщик
        pdf.font "DejaVu", size: 9 do
          pdf.text "#{client_preamble_name}, именуемый в дальнейшем «Покупатель», с одной стороны, и " \
                   "#{company.position_title} #{company.director_name.presence || company.name}, " \
                   "именуемый в дальнейшем «Поставщик», с другой стороны, именуемые в дальнейшем «Стороны», " \
                   "заключили настоящий Договор о нижеследующем:", align: :justify
        end
        pdf.move_down 8

        sections = contract_supply_sections
        sections.each do |title, items|
          pdf.font "DejaVu", size: 10, style: :bold do
            pdf.text title
          end
          pdf.move_down 3
          pdf.font "DejaVu", size: 9 do
            items.each do |item|
              pdf.text item, align: :justify
              pdf.move_down 2
            end
          end
          pdf.move_down 6
        end

        # Приложения (раздел 9.5): автоподстановка сметы и счёта из заказа
        pdf.font "DejaVu", size: 9 do
          supply_appendix_lines.each do |line|
            pdf.text line
            pdf.move_down 2
          end
        end

        # Реквизиты и подписи двумя столбцами
        pdf.move_down 10
        left_w = pdf.bounds.width / 2 - 10
        top_y = pdf.cursor
        pdf.font "DejaVu", size: 8.5 do
          pdf.bounding_box([ 0, top_y ], width: left_w) do
            pdf.text "ПОСТАВЩИК", style: :bold
            pdf.text company.name.to_s
            company.requisites_lines.each { |line| pdf.text line }
            pdf.text "Тел.: #{company.phone}" if company.phone.present?
            pdf.move_down 24
            pdf.text "__________________/ #{signature_initials} /"
          end
          pdf.bounding_box([ pdf.bounds.width / 2 + 10, top_y ], width: left_w) do
            pdf.text "ПОКУПАТЕЛЬ", style: :bold
            pdf.text client&.display_name.to_s
            client&.requisites_lines&.each { |line| pdf.text line }
            pdf.text "Тел.: #{client.phone}" if client&.phone.present?
            pdf.move_down 24
            pdf.text "__________________/ #{client&.short_name.presence || client&.name} /"
          end
        end
      end.render
    end

    # Приложения к договору поставки: Заказ покупателя (аналог — смета) + Счёт
    def supply_appendix_lines
      lines = []
      estimate = order.documents.find { |d| d.doc_type == "estimate" }
      if estimate
        lines << "— Заказ покупателя (смета): #{estimate.title} от #{l(estimate.document_date || estimate.created_at.to_date)}"
      else
        lines << "— Заказ покупателя (смета) № " + ("_" * 12) + " от " + ("_" * 14)
      end
      invoice = order.documents.find { |d| d.doc_type == "invoice" }
      if invoice
        lines << "— Счет на оплату: #{invoice.title} от #{l(invoice.document_date || invoice.created_at.to_date)}"
      else
        lines << "— Счет на оплату № " + ("_" * 12) + " от " + ("_" * 14)
      end
      lines
    end

    # Разделы договора поставки (текст из шаблона пользователя)
    def contract_supply_sections
      [
        [ "1. Предмет договора", [
          "1.1. В соответствии с настоящим Договором Поставщик обязуется поставить Покупателю комплект теплого пола «Тесла» (далее — Продукция) в соответствии с Заказом покупателя, который является неотъемлемой частью настоящего договора, а Покупатель принять и оплатить продукцию в соответствии с разделом 2 договора."
        ] ],
        [ "2. Сумма договора и порядок расчетов", [
          "2.1. Сумма настоящего Договора определяется в соответствии с Заказом покупателя.",
          "2.2. Оплата по настоящему Договору производится путем перечисления денежных средств на расчетный счет Поставщика или путем внесения наличных денежных средств в кассу Поставщика в следующем порядке:",
          "1) авансовый платеж в размере 100% от общей суммы Договора в течении 1 рабочего дня с момента подписания Договора.",
          "2.3. Цена продукции на период действия Договора является фиксированной и пересмотру не подлежит."
        ] ],
        [ "3. Условия и сроки поставки", [
          "3.1. Поставка продукции производится в соответствии с Заказом покупателя.",
          "3.2. Поставщик обязуется поставить Покупателю продукцию в течение 7 дней с момента получения денежных средств от Покупателя, если количество продукции, указанное в Заказе покупателя, имеется на складе Поставщика на момент подписания Договора.",
          "3.3. В случае отсутствия оборудования на складе в момент подписания Договора, срок поставки составляет от 10 до 45 календарных дней.",
          "3.4. Срок поставки может быть увеличен в случае:",
          "— задержки поставки от производителя;",
          "— логистических ограничений;",
          "— обстоятельств непреодолимой силы.",
          "3.5. Упаковка продукции должна обеспечивать ее сохранность при транспортировке и хранении.",
          "3.6. Грузополучателем продукции является Покупатель.",
          "3.7. Продукция доставляется Поставщиком на склад Получателя, указанного в заявке на доставку."
        ] ],
        [ "4. Обязательства сторон", [
          "4.1. Поставщик обязуется:",
          "4.1.1. Поставить продукцию в соответствии с условиями настоящего Договора.",
          "4.1.2. Поставщик гарантирует соответствие поставляемой продукции техническим условиям/иным требованиям при ее использовании и хранении и несет все расходы по замене или ремонту дефектной продукции, выявленной Покупателем в течение гарантийного срока, если дефект не зависит от условий хранения или неправильного обращения.",
          "4.1.3. Поставщик обязуется обеспечить гарантийное обслуживание поставляемой продукции в течение всего гарантийного срока, указанного в Гарантийном талоне производителя c момента приемки продукции, в случае если монтаж и эксплуатация велась согласно инструкции производителя.",
          "4.2. Покупатель обязуется:",
          "4.2.1. Принять и оплатить продукцию в соответствии с условиями настоящего Договора.",
          "4.3. Поставщик по согласованию с Покупателем имеет право на досрочную поставку продукции.",
          "4.4. Стороны не вправе передавать свои права и обязательства по настоящему Договору третьей стороне без письменного согласия другой Стороны."
        ] ],
        [ "5. Ответственность сторон", [
          "5.1. При нарушении сроков поставки продукции Поставщик, при наличии письменной претензии, уплачивает Покупателю пеню в размере 0,01 % стоимости не поставленной в срок (недопоставленной) продукции за каждый день просрочки, но не более 10 % указанной стоимости.",
          "5.2. При несоблюдении предусмотренных настоящим Договором сроков платежей Покупатель, при наличии письменной претензии, уплачивает Поставщику пеню в размере 0,01 % не перечисленной в срок суммы за каждый день просрочки, но не более 10% указанной суммы.",
          "5.3. Поставщик несет ответственность за качество, комплектацию и количество поставляемой продукции, а также за недопоставку продукции.",
          "5.4. Ответственность Сторон в иных случаях определяется в соответствии с законодательством Российской Федерации.",
          "5.5. Уплата неустойки не освобождает Стороны от исполнения обязательств по настоящему Договору."
        ] ],
        [ "6. Действие обстоятельств непреодолимой силы", [
          "6.1. Ни одна из Сторон не несет ответственность перед другой Стороной за неисполнение обязательств по настоящему Договору, обусловленное действием обстоятельств непреодолимой силы, т. е. чрезвычайных и непредотвратимых при данных условиях обстоятельств, в том числе: объявленная или фактическая война, гражданские волнения, эпидемии, блокада, эмбарго, пожары, землетрясения, наводнения и другие природные стихийные бедствия, а также издание актов государственных органов.",
          "6.2. Свидетельство, выданное соответствующим компетентным органом, является достаточным подтверждением наличия и продолжительности действия непреодолимой силы.",
          "6.3. Сторона, которая не исполняет обязательств по настоящему Договору вследствие действия непреодолимой силы, должна незамедлительно известить другую Сторону о таких обстоятельствах и их влиянии на исполнение обязательств по Договору.",
          "6.4. Если обстоятельства непреодолимой силы действуют на протяжении 3 (трех) последовательных месяцев, настоящий Договор может быть расторгнут любой из Сторон путем направления письменного уведомления другой Стороне."
        ] ],
        [ "7. Порядок разрешения споров", [
          "7.1. Все споры или разногласия, возникающие между Сторонами по настоящему Договору или в связи с ним, разрешаются путем переговоров между ними.",
          "7.2. В случае невозможности разрешения разногласий путем переговоров они подлежат рассмотрению в арбитражном суде согласно порядку, установленному законодательством Российской Федерации."
        ] ],
        [ "8. Порядок изменения и расторжения договора", [
          "8.1. Любые изменения и дополнения к настоящему Договору имеют силу только в том случае, если они оформлены в письменном виде и подписаны обеими Сторонами.",
          "8.2. Досрочное расторжение Договора может иметь место в соответствии с п. 6.4 настоящего Договора либо по соглашению Сторон, либо на основаниях, предусмотренных законодательством Российской Федерации.",
          "8.3. Сторона, решившая расторгнуть настоящий Договор, должна направить письменное уведомление о намерении расторгнуть настоящий Договор другой Стороне не позднее чем за 20 календарных дней до предполагаемого дня расторжения настоящего Договора."
        ] ],
        [ "9. Прочие условия", [
          "9.1. С момента подписания Сторонами настоящего Договора все предыдущие переговоры и переписка по нему теряют силу.",
          "9.2. Настоящий Договор вступает в действие с момента подписания настоящего договора и действует до исполнения Сторонами своих обязательств и завершения всех взаиморасчетов по Договору.",
          "9.3. В случае изменения у какой-либо из Сторон местонахождения, названия, банковских реквизитов и прочего она обязана в течение 10 (десяти) дней письменно известить об этом другую Сторону, причем в письме необходимо указать, что оно является неотъемлемой частью настоящего Договора.",
          "9.4. Настоящий Договор составлен в 2 (двух) экземплярах, имеющих одинаковую юридическую силу, по одному для каждой из сторон.",
          "9.5. Следующие приложения являются неотъемлемой частью настоящего Договора:"
        ] ]
      ]
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

    # Строка подписи ТОРГ-12 без рамок: label + должность + линия подписи + расшифровка
    def torg_sign_line(pdf, label, position, name, pos_x:, line_from:, line_to:, name_x:, position_caption: true)
      y = pdf.cursor
      pdf.draw_text label, at: [ 0, y ]
      pdf.draw_text position, at: [ pos_x, y ] if position.present?
      pdf.stroke_horizontal_line line_from, line_to, at: y - 2
      name_width = [ pdf.width_of(name.to_s, size: 7), 78 ].max
      pdf.stroke_horizontal_line name_x, name_x + name_width, at: y - 2
      pdf.draw_text name, at: [ name_x, y ] if name.present?
      pdf.font "DejaVu", size: 5 do
        pdf.draw_text "(должность)", at: [ pos_x, y - 9 ] if position_caption
        pdf.draw_text "(подпись)", at: [ line_from + 20, y - 9 ]
        pdf.draw_text "(расшифровка подписи)", at: [ name_x, y - 9 ]
      end
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
