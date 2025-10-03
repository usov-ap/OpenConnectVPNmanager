require 'open3'
require 'fileutils'

module VPNManager
  class Connection
    attr_reader :logger, :stats

    MAX_RECONNECT_ATTEMPTS = 5
    RECONNECT_DELAY = 5 # секунд

    def initialize
      @logger = VPNLogger.new
      @stats = Statistics.new
    end

    # Проверяет, запущен ли VPN
    def running?
      File.exist?(VPNManager::PID_FILE) && process_alive?(read_pid)
    end

    # Читает PID из файла
    def read_pid
      return nil unless File.exist?(VPNManager::PID_FILE)
      File.read(VPNManager::PID_FILE).strip.to_i
    rescue
      nil
    end

    # Проверяет, жив ли процесс
    def process_alive?(pid)
      return false unless pid && pid > 0
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    # Запускает VPN в фоновом режиме
    def start(master_password, auto_reconnect: false)
      if running?
        @logger.warn("VPN уже запущен (PID: #{read_pid})")
        return { success: false, message: "VPN уже запущен" }
      end

      begin
        creds = Crypto.load_credentials(master_password)
        @logger.info("Загружены учетные данные для сервера: #{creds[:server]}")

        @stats.connection_started

        # Запускаем в фоновом режиме
        pid = spawn_vpn_process(creds)

        if pid
          File.write(VPNManager::PID_FILE, pid.to_s, mode: 'w', perm: 0600)
          @logger.info("VPN запущен в фоновом режиме (PID: #{pid})")
          @stats.connection_successful

          # Автоматическое переподключение в отдельном потоке
          if auto_reconnect
            start_reconnect_monitor(master_password)
          end

          { success: true, message: "VPN успешно запущен (PID: #{pid})", pid: pid }
        else
          @logger.error("Не удалось запустить VPN процесс")
          @stats.connection_failed
          { success: false, message: "Не удалось запустить VPN" }
        end
      rescue => e
        @logger.error("Ошибка при запуске VPN: #{e.message}")
        @stats.connection_failed
        { success: false, message: "Ошибка: #{e.message}" }
      end
    end

    # Останавливает VPN
    def stop
      unless running?
        @logger.warn("VPN не запущен")
        return { success: false, message: "VPN не запущен" }
      end

      pid = read_pid

      begin
        # Останавливаем монитор переподключения
        stop_reconnect_monitor

        # Отправляем SIGTERM
        Process.kill('TERM', pid)
        @logger.info("Отправлен сигнал TERM процессу #{pid}")

        # Ждем завершения (до 5 секунд)
        5.times do
          sleep 1
          unless process_alive?(pid)
            break
          end
        end

        # Если процесс всё ещё жив, убиваем силой
        if process_alive?(pid)
          Process.kill('KILL', pid)
          @logger.warn("Процесс #{pid} убит принудительно (SIGKILL)")
        end

        File.delete(VPNManager::PID_FILE) if File.exist?(VPNManager::PID_FILE)
        @stats.connection_disconnected
        @logger.info("VPN остановлен")

        { success: true, message: "VPN остановлен" }
      rescue => e
        @logger.error("Ошибка при остановке VPN: #{e.message}")
        { success: false, message: "Ошибка: #{e.message}" }
      end
    end

    # Перезапускает VPN
    def restart(master_password, auto_reconnect: false)
      @logger.info("Перезапуск VPN...")
      stop if running?
      sleep 2
      start(master_password, auto_reconnect: auto_reconnect)
    end

    # Возвращает статус соединения
    def status
      if running?
        pid = read_pid
        uptime = @stats.current_session_duration

        {
          running: true,
          pid: pid,
          uptime: @stats.format_uptime(uptime),
          uptime_seconds: uptime
        }
      else
        { running: false }
      end
    end

    private

    # Запускает OpenConnect в фоновом режиме
    def spawn_vpn_process(creds)
      VPNManager.ensure_config_dir
      log_path = File.join(VPNManager::CONFIG_DIR, 'openconnect.log')

      # Создаем временный файл с паролем
      password_file = File.join(VPNManager::CONFIG_DIR, '.pass.tmp')
      File.write(password_file, creds[:password], mode: 'w', perm: 0600)

      begin
        # Запускаем openconnect
        pid = Process.spawn(
          'sudo', 'openconnect',
          '--user', creds[:username],
          '--passwd-on-stdin',
          '--background',
          creds[:server],
          in: password_file,
          out: log_path,
          err: log_path
        )

        Process.detach(pid)
        sleep 2 # Даём время на запуск

        # Проверяем, что процесс запустился
        if process_alive?(pid)
          @logger.info("OpenConnect процесс запущен успешно")
          pid
        else
          @logger.error("OpenConnect процесс завершился сразу после запуска")
          nil
        end
      ensure
        # Удаляем временный файл с паролем
        File.delete(password_file) if File.exist?(password_file)
      end
    end

    # Запускает монитор переподключения
    def start_reconnect_monitor(master_password)
      @monitor_thread = Thread.new do
        attempts = 0
        loop do
          sleep 10 # Проверяем каждые 10 секунд

          unless running?
            @logger.warn("VPN соединение потеряно, попытка переподключения...")
            @stats.reconnection

            attempts += 1
            if attempts > MAX_RECONNECT_ATTEMPTS
              @logger.error("Превышено максимальное количество попыток переподключения")
              break
            end

            sleep RECONNECT_DELAY
            result = start(master_password, auto_reconnect: false)

            if result[:success]
              @logger.info("Переподключение успешно")
              attempts = 0
            else
              @logger.error("Не удалось переподключиться: #{result[:message]}")
            end
          else
            attempts = 0 # Сбрасываем счётчик при работающем соединении
          end
        end
      end
    end

    # Останавливает монитор переподключения
    def stop_reconnect_monitor
      if @monitor_thread && @monitor_thread.alive?
        @monitor_thread.kill
        @monitor_thread = nil
        @logger.info("Монитор переподключения остановлен")
      end
    end
  end
end
