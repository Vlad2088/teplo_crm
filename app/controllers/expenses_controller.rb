class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[ edit update destroy ]

  # GET /expenses
  def index
    @expenses = Expense.includes(:expense_category).all
    @total = @expenses.sum(:amount)
  end

  # GET /expenses/new
  def new
    @expense = Expense.new(spent_on: Date.current)
  end

  # GET /expenses/1/edit
  def edit
  end

  # POST /expenses
  def create
    @expense = Expense.new(expense_params)
    @expense.user = current_user

    respond_to do |format|
      if @expense.save
        format.html { redirect_to expenses_path, notice: "Расход добавлен." }
        format.json { render :show, status: :created, location: @expense }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @expense.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /expenses/1
  def update
    respond_to do |format|
      if @expense.update(expense_params)
        format.html { redirect_to expenses_path, notice: "Расход обновлён." }
        format.json { render :show, status: :ok, location: @expense }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @expense.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /expenses/1
  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: "Расход удалён."
  end

  private

  def set_expense
    @expense = Expense.find(params.expect(:id))
  end

  def expense_params
    params.expect(expense: [ :amount, :spent_on, :expense_category_id, :payment_method, :comment, :receipt ])
  end
end
