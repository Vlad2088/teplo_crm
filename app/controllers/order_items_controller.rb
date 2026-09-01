class OrderItemsController < ApplicationController
  before_action :set_order
  before_action :set_order_item, only: %i[ destroy ]

  # POST /orders/:order_id/order_items
  def create
    @order_item = @order.order_items.build(order_item_params)

    respond_to do |format|
      if @order_item.save
        format.html { redirect_to @order, notice: "Позиция добавлена в заказ." }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { redirect_to @order, alert: @order_item.errors.full_messages.to_sentence }
        format.json { render json: @order_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /orders/:order_id/order_items/:id
  def destroy
    @order_item.destroy!
    respond_to do |format|
      format.html { redirect_to @order, notice: "Позиция удалена, товар возвращён на склад.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def set_order
      @order = Order.find(params.expect(:order_id))
    end

    def set_order_item
      @order_item = @order.order_items.find(params.expect(:id))
    end

    def order_item_params
      params.expect(order_item: [ :item_type, :item_id, :quantity, :unit_price ])
    end
end
