class Api::TasksController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_bot!
  wrap_parameters :task, include: %i[title comment due_date priority source]

  # POST /api/tasks
  def create
    user = User.find_by(email: ENV.fetch("TASKS_DEFAULT_USER", "admin@smartkam.ru"))
    return render json: { error: "default user not found" }, status: :internal_server_error unless user

    @task = Task.new(task_params)
    @task.user = user
    @task.source = params[:task][:source].presence || "telegram"

    if @task.save
      render json: { id: @task.id, title: @task.title, due_date: @task.due_date, priority: @task.priority }, status: :created
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_content
    end
  end

  # GET /api/tasks?scope=open
  def index
    scope = params[:scope].in?(%w[done all]) ? params[:scope] : "open"
    tasks = case scope
            when "done"
              Task.done.order(completed_at: :desc).limit(20)
            when "all"
              Task.order(created_at: :desc).limit(50)
            else
              Task.open.order(priority: :desc, due_date: :asc)
            end
    render json: tasks.map { |t| task_json(t) }
  end

  # PATCH /api/tasks/:id/done
  def done
    @task = Task.find(params[:id])
    if @task.open?
      @task.update!(status: :done, completed_at: Time.current)
      render json: task_json(@task)
    else
      render json: task_json(@task)
    end
  end

  private

  def authenticate_bot!
    authenticate_or_request_with_http_token do |token, _|
      ActiveSupport::SecurityUtils.secure_compare(token.to_s, ENV.fetch("TASKS_API_TOKEN", ""))
    end
  end

  def task_params
    params.expect(task: [:title, :comment, :due_date, :priority, :source])
  end

  def task_json(t)
    {
      id: t.id,
      title: t.title,
      comment: t.comment,
      due_date: t.due_date,
      priority: t.priority,
      status: t.status,
      overdue: t.overdue?,
      today: t.due_today?,
      attachment: t.attachment.attached? ? rails_blob_url(t.attachment, disposition: "attachment") : nil
    }
  end
end
