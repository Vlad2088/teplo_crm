class ReportsController < ApplicationController
  # GET /reports/money?period=month|quarter|year|custom&from=YYYY-MM-DD&to=YYYY-MM-DD
  def money
    @from, @to = report_period

    @payments = Payment.where(paid_at: @from.beginning_of_day..@to.end_of_day)
                       .includes(order: :client).order(:paid_at).to_a
    @expenses = Expense.for_period(@from, @to).includes(:expense_category).to_a

    @income_total = @payments.sum(&:amount)
    @income_cash = @payments.select(&:cash?).sum(&:amount)
    @income_cashless = @payments.select(&:cashless?).sum(&:amount)

    @expense_total = @expenses.sum(&:amount)
    @expense_by_category = @expenses.group_by(&:expense_category)
                                    .transform_values { |list| list.sum(&:amount) }
                                    .sort_by { |_category, sum| -sum }

    @balance = @income_total - @expense_total

    @payments_by_order = @payments.group_by(&:order)
                                  .transform_values { |list| list.sum(&:amount) }
                                  .sort_by { |_order, sum| -sum }

    @operations = @payments.map { |payment| income_operation(payment) } +
                  @expenses.map { |expense| expense_operation(expense) }
    @operations.sort_by! { |op| [ op[:date], op[:income] ? 1 : 0 ] }.reverse!
  end

  # GET /reports/goods?period=month|quarter|year|custom&from=..&to=..&category=warm_floor
  def goods
    @from, @to = report_period
    @category = params[:category].presence

    products = @category.present? ? Product.where(category: @category).order(:name) : Product.all.order(:name)

    movements = StockMovement.where(created_at: @from.beginning_of_day..@to.end_of_day)
                             .where(product_id: products.ids)
                             .includes(:product).to_a

    # движения ПОСЛЕ конца периода — чтобы вычислить остаток на конец периода
    after_by_product = StockMovement.where(created_at: @to.end_of_day..)
                                    .where(product_id: products.ids)
                                    .group(:product_id, :movement_type).sum(:quantity_change)

    @rows = products.map do |product|
      product_movements = movements.select { |m| m.product_id == product.id }
      in_qty = product_movements.select(&:in?).sum(&:quantity_change)
      out_qty = product_movements.select(&:out?).sum(&:quantity_change)
      after_in = after_by_product[[ product.id, "in" ]].to_i
      after_out = after_by_product[[ product.id, "out" ]].to_i
      ending_stock = product.stock_quantity - (after_in - after_out)
      {
        product: product,
        in_qty: in_qty,
        out_qty: out_qty,
        ending_stock: ending_stock,
        stock_value: ending_stock * (product.purchase_price || 0)
      }
    end
    @rows.select! { |row| row[:in_qty].positive? || row[:out_qty].positive? }

    @total_stock_value = Product.all.sum { |p| p.stock_quantity * (p.purchase_price || 0) }
    @top_consumed = @rows.reject { |row| row[:out_qty].zero? }.sort_by { |row| -row[:out_qty] }.first(5)
  end

  private

  def report_period
    case params[:period]
    when "quarter" then [ Date.current.beginning_of_quarter, Date.current.end_of_quarter ]
    when "year" then [ Date.current.beginning_of_year, Date.current.end_of_year ]
    when "custom" then [ parse_date(params[:from], Date.current.beginning_of_month),
                        parse_date(params[:to], Date.current.end_of_month) ]
    else [ Date.current.beginning_of_month, Date.current.end_of_month ]
    end
  end

  def parse_date(value, fallback)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError, Date::Error
    fallback
  end

  def income_operation(payment)
    description = "Оплата заказа ##{payment.order_id}"
    description += " — #{payment.description}" if payment.description.present?
    { date: payment.paid_at.to_date, income: true, amount: payment.amount,
      badge_kind: :payment_type, badge_value: payment.payment_type, description: description }
  end

  def expense_operation(expense)
    description = expense.expense_category.name
    description += " — #{expense.comment}" if expense.comment.present?
    { date: expense.spent_on, income: false, amount: expense.amount,
      badge_kind: :payment_method, badge_value: expense.payment_method, description: description }
  end
end
