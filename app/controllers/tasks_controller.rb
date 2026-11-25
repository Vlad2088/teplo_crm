class TasksController < ApplicationController
  before_action :set_task, only: %i[edit update destroy complete reopen]

  # GET /tasks
  def index
    scope = params[:scope].in?(%w[done all]) ? params[:scope] : "open"
    base = Task.order(priority: :desc, due_date: :asc).includes(:user)
    case scope
    when "done"
      @tasks = base.done.order(completed_at: :desc)
    when "all"
      @tasks = base
    else
      @overdue  = Task.overdue.includes(:user)
      @due_today = Task.due_today.includes(:user)
      @upcoming = Task.upcoming.includes(:user)
      @no_date  = Task.no_due_date.includes(:user)
    end
    @scope = scope
    @open_count = Task.open.count
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  # GET /tasks/1/edit
  def edit
  end

  # POST /tasks
  def create
    @task = Task.new(task_params)
    @task.user = current_user

    if @task.save
      TaskNotifier.task_created(@task)
      redirect_to tasks_path, notice: "Задача создана."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /tasks/1
  def update
    if @task.update(task_params)
      redirect_to tasks_path, notice: "Задача обновлена."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # PATCH /tasks/1/complete
  def complete
    @task.update(status: :done, completed_at: Time.current)
    TaskNotifier.task_completed(@task)
    redirect_back_or_tasks("Задача выполнена.")
  end

  # PATCH /tasks/1/reopen
  def reopen
    @task.update(status: :open, completed_at: nil)
    redirect_back_or_tasks("Задача снова открыта.")
  end

  # DELETE /tasks/1
  def destroy
    @task.destroy!
    redirect_back_or_tasks("Задача удалена.")
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def redirect_back_or_tasks(notice)
    redirect_back fallback_location: tasks_path, notice: notice
  end

  def task_params
    params.expect(task: [:title, :comment, :due_date, :priority, :attachment])
  end
end
