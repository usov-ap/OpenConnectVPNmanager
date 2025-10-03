require 'logger'
require 'fileutils'

module VPNManager
  class VPNLogger
    attr_reader :logger

    def initialize
      VPNManager.ensure_config_dir

      @logger = Logger.new(VPNManager::LOG_FILE, 10, 1024000) # 10 файлов по 1MB
      @logger.level = Logger::INFO
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} : #{msg}\n"
      end
    end

    def info(message)
      @logger.info(message)
    end

    def warn(message)
      @logger.warn(message)
    end

    def error(message)
      @logger.error(message)
    end

    def debug(message)
      @logger.debug(message)
    end

    def fatal(message)
      @logger.fatal(message)
    end

    # Читает последние N строк из лога
    def tail(lines = 50)
      return [] unless File.exist?(VPNManager::LOG_FILE)

      content = File.readlines(VPNManager::LOG_FILE)
      content.last(lines)
    end
  end
end
