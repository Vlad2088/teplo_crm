class ExpenseCategoriesController < ApplicationController
  before_action :set_expense_category, only: %i[ edit update destroy ]

  # GET /expense_categories
  def index
    @expense_categories = ExpenseCategory.order(:name)
  end

  # GET /expense_categories/new
  def new
    @expense_category = ExpenseCategory.new
  end

  # GET /expense_categories/1/edit
  def edit
  end

  # POST /expense_categories
  def create
    @expense_category = ExpenseCategory.new(expense_category_params)

    respond_to do |format|
      if @expense_category.save
        format.html { redirect_to expense_categories_path, notice: "Статья расходов добавлена." }
        format.json { render :show, status: :created, location: @expense_category }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @expense_category.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /expense_categories/1
  def update
    respond_to do |format|
      if @expense_category.update(expense_category_params)
        format.html { redirect_to expense_categories_path, notice: "Статья расходов обновлена." }
        format.json { render :show, status: :ok, location: @expense_category }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @expense_category.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /expense_categories/1
  def destroy
    if @expense_category.destroy
      redirect_to expense_categories_path, notice: "Статья расходов удалена."
    else
      redirect_to expense_categories_path, alert: @expense_category.errors.full_messages.to_sentence
    end
  end

  private

  def set_expense_category
    @expense_category = ExpenseCategory.find(params.expect(:id))
  end

  def expense_category_params
    params.expect(expense_category: [ :name ])
  end
end
