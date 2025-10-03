require 'thor'
require 'io/console'

module VPNManager
  class CLI < Thor
    def initialize(*args)
      super
      @connection = Connection.new
    end

    desc "setup", "Настройка VPN (сохранение учетных данных)"
    def setup
      puts "=== Настройка OpenConnect VPN ==="
      puts

      print "Введите адрес VPN сервера: "
      server = STDIN.gets.chomp

      print "Введите имя пользователя: "
      username = STDIN.gets.chomp

      print "Введите пароль VPN: "
      password = STDIN.noecho(&:gets).chomp
      puts

      print "Создайте мастер-пароль для шифрования: "
      master_password = STDIN.noecho(&:gets).chomp
      puts

      print "Подтвердите мастер-пароль: "
      master_password_confirm = STDIN.noecho(&:gets).chomp
      puts

      if master_password != master_password_confirm
        puts "Ошибка: пароли не совпадают!"
        exit 1
      end

      if master_password.length < 8
        puts "Ошибка: мастер-пароль должен быть не менее 8 символов!"
        exit 1
      end

      begin
        Crypto.save_credentials(server, username, password, master_password)
        puts
        puts "✓ Учетные данные успешно сохранены и зашифрованы!"
        puts "✓ Конфигурация сохранена в: #{VPNManager::CONFIG_DIR}"
      rescue => e
        puts "Ошибка при сохранении: #{e.message}"
        exit 1
      end
    end

    desc "start", "Запустить VPN соединение"
    method_option :auto_reconnect, type: :boolean, default: false, aliases: '-r',
                  desc: "Включить автоматическое переподключение"
    def start
      master_password = ask_master_password

      result = @connection.start(master_password, auto_reconnect: options[:auto_reconnect])

      if result[:success]
        puts "✓ #{result[:message]}"
        puts "  Автопереподключение: #{options[:auto_reconnect] ? 'включено' : 'выключено'}"
      else
        puts "✗ #{result[:message]}"
        exit 1
      end
    end

    desc "stop", "Остановить VPN соединение"
    def stop
      result = @connection.stop

      if result[:success]
        puts "✓ #{result[:message]}"
      else
        puts "✗ #{result[:message]}"
        exit 1
      end
    end

    desc "restart", "Перезапустить VPN соединение"
    method_option :auto_reconnect, type: :boolean, default: false, aliases: '-r',
                  desc: "Включить автоматическое переподключение"
    def restart
      master_password = ask_master_password

      result = @connection.restart(master_password, auto_reconnect: options[:auto_reconnect])

      if result[:success]
        puts "✓ #{result[:message]}"
      else
        puts "✗ #{result[:message]}"
        exit 1
      end
    end

    desc "status", "Показать статус VPN соединения"
    def status
      status = @connection.status

      puts "=== Статус VPN ==="
      if status[:running]
        puts "Состояние: ПОДКЛЮЧЕН"
        puts "PID: #{status[:pid]}"
        puts "Время работы: #{status[:uptime]}"
      else
        puts "Состояние: ОТКЛЮЧЕН"
      end
    end

    desc "stats", "Показать статистику использования"
    def stats
      @connection.update_traffic_stats if @connection.running?
      stats = @connection.stats
      puts stats.to_s
    end

    desc "reset_stats", "Сбросить всю статистику"
    def reset_stats
      print "Вы уверены, что хотите сбросить всю статистику? (y/N): "
      answer = STDIN.gets.chomp.downcase

      if answer == 'y' || answer == 'yes'
        @connection.stats.reset_stats
        puts "✓ Статистика сброшена"
      else
        puts "Отменено"
      end
    end

    desc "logs", "Показать последние записи из лога"
    method_option :lines, type: :numeric, default: 50, aliases: '-n',
                  desc: "Количество строк для отображения"
    def logs
      log_lines = @connection.logger.tail(options[:lines])

      if log_lines.empty?
        puts "Лог пуст"
      else
        puts "=== Последние #{log_lines.size} записей лога ==="
        puts log_lines.join
      end
    end

    desc "version", "Показать версию программы"
    def version
      puts "VPN Manager v#{VPNManager::VERSION}"
    end

    private

    def ask_master_password
      print "Введите мастер-пароль: "
      password = STDIN.noecho(&:gets).chomp
      puts
      password
    end
  end
end
