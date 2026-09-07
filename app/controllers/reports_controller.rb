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
