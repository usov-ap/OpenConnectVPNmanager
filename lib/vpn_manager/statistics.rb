require 'json'
require 'time'

module VPNManager
  class Statistics
    attr_accessor :total_connections, :successful_connections, :failed_connections,
                  :total_uptime, :last_connection, :last_disconnect,
                  :reconnect_count, :data_transferred

    def initialize
      VPNManager.ensure_config_dir
      load_stats
    end

    # Загружает статистику из файла
    def load_stats
      if File.exist?(VPNManager::STATS_FILE)
        data = JSON.parse(File.read(VPNManager::STATS_FILE), symbolize_names: true)
        @total_connections = data[:total_connections] || 0
        @successful_connections = data[:successful_connections] || 0
        @failed_connections = data[:failed_connections] || 0
        @total_uptime = data[:total_uptime] || 0
        @last_connection = data[:last_connection] ? Time.parse(data[:last_connection]) : nil
        @last_disconnect = data[:last_disconnect] ? Time.parse(data[:last_disconnect]) : nil
        @reconnect_count = data[:reconnect_count] || 0
        @data_transferred = data[:data_transferred] || { sent: 0, received: 0 }
        @session_start = data[:session_start] ? Time.parse(data[:session_start]) : nil
      else
        reset_stats
      end
    end

    # Сбрасывает всю статистику
    def reset_stats
      @total_connections = 0
      @successful_connections = 0
      @failed_connections = 0
      @total_uptime = 0
      @last_connection = nil
      @last_disconnect = nil
      @reconnect_count = 0
      @data_transferred = { sent: 0, received: 0 }
      @session_start = nil
      save_stats
    end

    # Сохраняет статистику в файл
    def save_stats
      data = {
        total_connections: @total_connections,
        successful_connections: @successful_connections,
        failed_connections: @failed_connections,
        total_uptime: @total_uptime,
        last_connection: @last_connection&.iso8601,
        last_disconnect: @last_disconnect&.iso8601,
        reconnect_count: @reconnect_count,
        data_transferred: @data_transferred,
        session_start: @session_start&.iso8601
      }
      File.write(VPNManager::STATS_FILE, JSON.pretty_generate(data), mode: 'w', perm: 0600)
    end

    # Регистрирует начало соединения
    def connection_started
      @total_connections += 1
      @last_connection = Time.now
      @session_start = Time.now
      save_stats
    end

    # Регистрирует успешное соединение
    def connection_successful
      @successful_connections += 1
      save_stats
    end

    # Регистрирует отключение
    def connection_disconnected
      if @session_start
        session_duration = Time.now - @session_start
        @total_uptime += session_duration.to_i
        @session_start = nil
      end
      @last_disconnect = Time.now
      save_stats
    end

    # Регистрирует неудачное соединение
    def connection_failed
      @failed_connections += 1
      save_stats
    end

    # Регистрирует переподключение
    def reconnection
      @reconnect_count += 1
      save_stats
    end

    # Обновляет статистику передачи данных
    def update_data_transfer(sent: 0, received: 0)
      @data_transferred[:sent] += sent
      @data_transferred[:received] += received
      save_stats
    end

    # Возвращает текущую сессию в секундах
    def current_session_duration
      return 0 unless @session_start
      (Time.now - @session_start).to_i
    end

    # Форматирует время работы в читаемый вид
    def format_uptime(seconds)
      days = seconds / 86400
      hours = (seconds % 86400) / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60

      parts = []
      parts << "#{days}д" if days > 0
      parts << "#{hours}ч" if hours > 0
      parts << "#{minutes}м" if minutes > 0
      parts << "#{secs}с" if secs > 0 || parts.empty?

      parts.join(' ')
    end

    # Форматирует размер данных
    def format_bytes(bytes)
      units = ['B', 'KB', 'MB', 'GB', 'TB']
      unit_index = 0
      size = bytes.to_f

      while size >= 1024 && unit_index < units.length - 1
        size /= 1024
        unit_index += 1
      end

      "#{size.round(2)} #{units[unit_index]}"
    end

    # Выводит статистику в текстовом виде
    def to_s
      lines = []
      lines << "=== VPN Статистика ==="
      lines << ""
      lines << "Всего подключений: #{@total_connections}"
      lines << "Успешных: #{@successful_connections}"
      lines << "Неудачных: #{@failed_connections}"
      lines << "Переподключений: #{@reconnect_count}"
      lines << ""
      lines << "Общее время работы: #{format_uptime(@total_uptime)}"
      lines << "Текущая сессия: #{format_uptime(current_session_duration)}" if @session_start
      lines << ""
      lines << "Последнее подключение: #{@last_connection&.strftime('%Y-%m-%d %H:%M:%S') || 'Никогда'}"
      lines << "Последнее отключение: #{@last_disconnect&.strftime('%Y-%m-%d %H:%M:%S') || 'Никогда'}"
      lines << ""
      lines << "Данные отправлено: #{format_bytes(@data_transferred[:sent])}"
      lines << "Данные получено: #{format_bytes(@data_transferred[:received])}"
      lines << "Всего: #{format_bytes(@data_transferred[:sent] + @data_transferred[:received])}"
      lines << ""

      success_rate = @total_connections > 0 ? (@successful_connections.to_f / @total_connections * 100).round(2) : 0
      lines << "Успешность: #{success_rate}%"

      lines.join("\n")
    end
  end
end
