class StockMovementsController < ApplicationController
  before_action :set_stock_movement, only: %i[ show edit update destroy ]

  # GET /stock_movements or /stock_movements.json
  def index
    @stock_movements = StockMovement.all
  end

  # GET /stock_movements/1 or /stock_movements/1.json
  def show
  end

  # GET /stock_movements/new
  def new
    @stock_movement = StockMovement.new
  end

  # GET /stock_movements/1/edit
  def edit
  end

  # POST /stock_movements or /stock_movements.json
  def create
    @stock_movement = StockMovement.new(stock_movement_params)

    respond_to do |format|
      if @stock_movement.save
        format.html { redirect_to @stock_movement, notice: "Stock movement was successfully created." }
        format.json { render :show, status: :created, location: @stock_movement }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @stock_movement.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /stock_movements/1 or /stock_movements/1.json
  def update
    respond_to do |format|
      if @stock_movement.update(stock_movement_params)
        format.html { redirect_to @stock_movement, notice: "Stock movement was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @stock_movement }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @stock_movement.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /stock_movements/1 or /stock_movements/1.json
  def destroy
    @stock_movement.destroy!

    respond_to do |format|
      format.html { redirect_to stock_movements_path, notice: "Stock movement was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stock_movement
      @stock_movement = StockMovement.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def stock_movement_params
      params.expect(stock_movement: [ :product_id, :quantity_change, :movement_type, :order_id ])
    end
end
