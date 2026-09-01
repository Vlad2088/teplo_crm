class PaymentsController < ApplicationController
  before_action :set_order
  before_action :set_payment, only: %i[ destroy ]

  # POST /orders/:order_id/payments
  def create
    @payment = @order.payments.build(payment_params)

    respond_to do |format|
      if @payment.save
        format.html { redirect_to @order, notice: "Оплата внесена." }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { redirect_to @order, alert: @payment.errors.full_messages.to_sentence }
        format.json { render json: @payment.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /orders/:order_id/payments/:id
  def destroy
    @payment.destroy!
    respond_to do |format|
      format.html { redirect_to @order, notice: "Оплата удалена.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def set_order
      @order = Order.find(params.expect(:order_id))
    end

    def set_payment
      @payment = @order.payments.find(params.expect(:id))
    end

    def payment_params
      params.expect(payment: [ :amount, :payment_type, :paid_at, :description ])
    end
end
