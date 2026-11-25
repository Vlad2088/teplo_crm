class Task < ApplicationRecord
  belongs_to :user
  has_one_attached :attachment

  enum :priority, { low: 0, medium: 1, high: 2 }
  enum :status, { open: 0, done: 1 }

  validates :title, presence: true

  scope :overdue, -> { open.where(due_date: ...Date.current).order(:due_date) }
  scope :due_today, -> { open.where(due_date: Date.current) }
  scope :upcoming, -> { open.where("due_date > ?", Date.current).order(:due_date) }
  scope :no_due_date, -> { open.where(due_date: nil).order(created_at: :desc) }

  PRIORITY_BADGE = {
    "low" => ["Низкий", "bg-gray-100 text-gray-700"],
    "medium" => ["Средний", "bg-blue-100 text-blue-700"],
    "high" => ["Высокий", "bg-red-100 text-red-700"]
  }.freeze

  def overdue?
    open? && due_date.present? && due_date < Date.current
  end

  def due_today?
    open? && due_date == Date.current
  end

  def priority_badge
    PRIORITY_BADGE.fetch(priority, PRIORITY_BADGE["low"])
  end
end
