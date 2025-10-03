require 'spec_helper'
require 'tempfile'

RSpec.describe VPNManager::Connection do
  let(:temp_dir) { Dir.mktmpdir }
  let(:pid_file) { File.join(temp_dir, 'vpn.pid') }
  let(:connection) { described_class.new }
  let(:master_password) { 'test_master_password' }

  before do
    stub_const('VPNManager::CONFIG_DIR', temp_dir)
    stub_const('VPNManager::PID_FILE', pid_file)
    stub_const('VPNManager::CREDENTIALS_FILE', File.join(temp_dir, 'credentials.enc'))
    stub_const('VPNManager::STATS_FILE', File.join(temp_dir, 'stats.json'))
    stub_const('VPNManager::LOG_FILE', File.join(temp_dir, 'vpn.log'))
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#running?' do
    it 'возвращает false, если VPN не запущен' do
      expect(connection.running?).to be false
    end

    it 'возвращает false, если PID файл существует, но процесс мертв' do
      File.write(pid_file, '99999')
      expect(connection.running?).to be false
    end

    it 'возвращает true, если процесс запущен' do
      File.write(pid_file, Process.pid.to_s)
      expect(connection.running?).to be true
    end
  end

  describe '#read_pid' do
    it 'возвращает nil, если файл не существует' do
      expect(connection.read_pid).to be_nil
    end

    it 'читает PID из файла' do
      File.write(pid_file, '12345')
      expect(connection.read_pid).to eq(12345)
    end
  end

  describe '#process_alive?' do
    it 'возвращает true для текущего процесса' do
      expect(connection.send(:process_alive?, Process.pid)).to be true
    end

    it 'возвращает false для несуществующего процесса' do
      expect(connection.send(:process_alive?, 99999)).to be false
    end

    it 'возвращает false для nil' do
      expect(connection.send(:process_alive?, nil)).to be false
    end

    it 'возвращает false для нуля' do
      expect(connection.send(:process_alive?, 0)).to be false
    end
  end

  describe '#status' do
    it 'возвращает статус "не запущен"' do
      status = connection.status

      expect(status[:running]).to be false
    end

    it 'возвращает статус "запущен" с информацией' do
      File.write(pid_file, Process.pid.to_s)
      connection.stats.connection_started

      status = connection.status

      expect(status[:running]).to be true
      expect(status[:pid]).to eq(Process.pid)
      expect(status[:uptime]).to be_a(String)
      expect(status[:uptime_seconds]).to be >= 0
    end
  end

  describe '#start' do
    before do
      # Сохраняем тестовые учетные данные
      VPNManager::Crypto.save_credentials(
        'vpn.example.com',
        'testuser',
        'testpass',
        master_password
      )
    end

    it 'возвращает ошибку, если VPN уже запущен' do
      allow(connection).to receive(:running?).and_return(true)
      allow(connection).to receive(:read_pid).and_return(12345)

      result = connection.start(master_password)

      expect(result[:success]).to be false
      expect(result[:message]).to include('уже запущен')
    end

    it 'возвращает ошибку при неверном мастер-пароле' do
      result = connection.start('wrong_password')

      expect(result[:success]).to be false
      expect(result[:message]).to include('Ошибка')
    end
  end

  describe '#stop' do
    it 'возвращает ошибку, если VPN не запущен' do
      result = connection.stop

      expect(result[:success]).to be false
      expect(result[:message]).to include('не запущен')
    end
  end
end
