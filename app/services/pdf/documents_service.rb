require "prawn/table"
# Генерация печатных форм (PDF) для документов заказа: смета и акт
class Pdf::DocumentsService
  FONT_DIR = "/usr/share/fonts/truetype/dejavu".freeze

  def initialize(document)
    @document = document
    @order = document.order
    @company = CompanySetting.current
  end

  def render
    case @document.doc_type
    when "estimate" then render_estimate
    when "act" then render_act
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
    def draw_header(pdf, doc_title)
      pdf.bounding_box([ 0, pdf.cursor ], width: 300) do
        pdf.font "DejaVu", size: 10 do
          pdf.text company.name.to_s, size: 12, style: :bold
          pdf.text company.position_title.to_s if company.position_title.present?
          pdf.text "ИНН #{company.inn}" if company.inn.present?
          pdf.text company.phone.to_s if company.phone.present?
          pdf.text company.address.to_s if company.address.present?
        end
      end
      pdf.bounding_box([ pdf.bounds.right - 200, pdf.cursor ], width: 200) do
        pdf.font "DejaVu", size: 16, style: :bold do
          pdf.text doc_title, align: :right
        end
        pdf.font "DejaVu", size: 10 do
          pdf.text "№ #{document.title.to_s.gsub(/^.*№\s*/, '')}", align: :right if document.title.to_s.include?("№")
          pdf.text("от #{l(document.document_date || Date.current)}", align: :right) if document.document_date
        end
      end
      pdf.move_down 20
      pdf.stroke_horizontal_rule
      pdf.move_down 16
    end

    # Блок заказчика и объекта
    def draw_customer(pdf)
      client = order.client
      pdf.font "DejaVu", size: 10 do
        pdf.text "<b>Заказчик:</b> #{client&.name}", inline_format: true
        pdf.text "ИНН #{client.inn}" if client&.inn.present?
        pdf.text client&.phone.to_s if client&.phone.present?
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

    # Итоги: сумма, скидка, ИТОГО
    def draw_totals(pdf, items)
      items_total = items.sum(&:total_price)
      pdf.move_down 12

      if order.discount_percent.to_d > 0
        discount_amount = items_total * order.discount_percent / 100
        total_due = items_total - discount_amount
        draw_total_row(pdf, "Сумма:", items_total)
        draw_total_row(pdf, "Скидка (#{order.discount_percent}%):", -discount_amount)
        draw_total_row(pdf, "ИТОГО:", total_due, bold: true, size: 13)
      else
        draw_total_row(pdf, "ИТОГО:", items_total, bold: true, size: 13)
      end
    end

    def draw_total_row(pdf, label, value, bold: false, size: 11)
      pdf.font "DejaVu", size: size, style: (bold ? :bold : :normal) do
        pdf.float do
          pdf.text_box label, at: [ pdf.bounds.right - 320, pdf.cursor ], width: 200, align: :right
        end
        pdf.text_box money(value), at: [ pdf.bounds.right - 110, pdf.cursor ], width: 110, align: :right
        pdf.move_down size + 4
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
        pdf.draw_text(company.director_name.to_s, at: [ 0, pdf.cursor ]) if company.director_name.present?
        pdf.draw_text(order.client&.name.to_s, at: [ pdf.bounds.right - 150, pdf.cursor ]) if order.client
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

    def format_qty(value)
      value.to_s.gsub(/\.0$/, "")
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

    # Заглушка для типов без макета (счёт, договор, УПД — следующие этапы)
    def render_stub
      Prawn::Document.new(pdf_options) do |pdf|
        setup_fonts(pdf)
        draw_header(pdf, document.doc_type.upcase)
        pdf.text "Печатная форма для этого типа документа будет добавлена позже.", color: "9CA3AF"
      end.render
    end
end
