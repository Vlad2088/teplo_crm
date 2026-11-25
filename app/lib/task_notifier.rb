# frozen_string_literal: true

# Sends Telegram notifications about task events to the owner chat.
# Fire-and-forget: failures are logged, never raised (notification must not break CRUD).
class TaskNotifier
  BOT_TOKEN = ENV.fetch("TASKS_NOTIFY_BOT_TOKEN", "")
  CHAT_ID = ENV.fetch("TASKS_NOTIFY_CHAT_ID", "")
  TG_IPS = %w[149.154.167.220 149.154.166.220 149.154.175.53 149.154.164.250].freeze

  def self.task_created(task)
    return unless BOT_TOKEN.present? && CHAT_ID.present?

    author = task.user&.email || "кто-то"
    bits = ["📋 Новая задача ##{task.id}: #{task.title}"]
    bits << "от #{author}"
    bits << "срок #{I18n.l(task.due_date, format: :short)}" if task.due_date
    pr_ru = { "high" => "высокий", "medium" => "средний", "low" => "низкий" }.fetch(task.priority, "")
    bits << "приоритет #{pr_ru}" unless pr_ru.empty?
    bits << "📎 файл" if task.attachment.attached?
    bits << "(источник: #{task.source})"
    send_async(bits.join(", "))
  end

  def self.task_completed(task)
    return unless BOT_TOKEN.present? && CHAT_ID.present?
    send_async("✅ Задача ##{task.id} выполнена: #{task.title}")
  end

  def self.send_async(text)
    Thread.new do
      send(text)
    rescue StandardError => e
      Rails.logger.warn("[TaskNotifier] send failed: #{e.class}: #{e.message}")
    end
  end

  def self.send(text)
    body = { chat_id: CHAT_ID, text: text }.to_json
    TG_IPS.each do |ip|
      begin
        s = Socket.tcp(ip, 443, connect_timeout: 8)
      rescue StandardError
        next
      end
      begin
        ctx = OpenSSL::SSL::SSLContext.new
        ss = OpenSSL::SSL::SSLSocket.new(s, ctx)
        ss.hostname = "api.telegram.org"
        ss.connect
        req = "POST /bot#{BOT_TOKEN}/sendMessage HTTP/1.1\r\n" \
              "Host: api.telegram.org\r\nContent-Type: application/json\r\n" \
              "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
        ss.write(req)
        resp = ss.read(2048)
        ss.close
        return true if resp&.start_with?("HTTP/1.1 200")
      rescue StandardError
        next
      ensure
        s.close unless s.closed?
      end
    end
    false
  end
end
