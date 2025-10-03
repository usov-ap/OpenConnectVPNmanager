require_relative 'vpn_manager/crypto'
require_relative 'vpn_manager/connection'
require_relative 'vpn_manager/logger'
require_relative 'vpn_manager/statistics'
require_relative 'vpn_manager/cli'

module VPNManager
  VERSION = '1.0.1'

  CONFIG_DIR = File.join(Dir.home, '.vpn_manager')
  CREDENTIALS_FILE = File.join(CONFIG_DIR, 'credentials.enc')
  STATS_FILE = File.join(CONFIG_DIR, 'stats.json')
  LOG_FILE = File.join(CONFIG_DIR, 'vpn.log')
  PID_FILE = File.join(CONFIG_DIR, 'vpn.pid')

  def self.ensure_config_dir
    FileUtils.mkdir_p(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
  end
end
