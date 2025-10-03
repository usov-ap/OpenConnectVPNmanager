require 'spec_helper'
require 'tempfile'

RSpec.describe VPNManager::Statistics do
  let(:temp_dir) { Dir.mktmpdir }
  let(:stats_file) { File.join(temp_dir, 'stats.json') }

  before do
    stub_const('VPNManager::CONFIG_DIR', temp_dir)
    stub_const('VPNManager::STATS_FILE', stats_file)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#initialize' do
    it 'инициализирует статистику с нулевыми значениями' do
      stats = described_class.new

      expect(stats.total_connections).to eq(0)
      expect(stats.successful_connections).to eq(0)
      expect(stats.failed_connections).to eq(0)
      expect(stats.total_uptime).to eq(0)
    end
  end

  describe '#connection_started' do
    it 'увеличивает счетчик подключений' do
      stats = described_class.new
      expect { stats.connection_started }.to change { stats.total_connections }.by(1)
    end

    it 'устанавливает время последнего подключения' do
      stats = described_class.new
      stats.connection_started

      expect(stats.last_connection).to be_a(Time)
      expect(stats.last_connection).to be_within(1).of(Time.now)
    end
  end

  describe '#connection_successful' do
    it 'увеличивает счетчик успешных подключений' do
      stats = described_class.new
      expect { stats.connection_successful }.to change { stats.successful_connections }.by(1)
    end
  end

  describe '#connection_failed' do
    it 'увеличивает счетчик неудачных подключений' do
      stats = described_class.new
      expect { stats.connection_failed }.to change { stats.failed_connections }.by(1)
    end
  end

  describe '#reconnection' do
    it 'увеличивает счетчик переподключений' do
      stats = described_class.new
      expect { stats.reconnection }.to change { stats.reconnect_count }.by(1)
    end
  end

  describe '#connection_disconnected' do
    it 'обновляет время работы' do
      stats = described_class.new
      stats.connection_started

      sleep 1
      stats.connection_disconnected

      expect(stats.total_uptime).to be >= 1
    end

    it 'устанавливает время отключения' do
      stats = described_class.new
      stats.connection_started
      stats.connection_disconnected

      expect(stats.last_disconnect).to be_a(Time)
    end
  end

  describe '#update_data_transfer' do
    it 'обновляет статистику переданных данных' do
      stats = described_class.new
      stats.update_data_transfer(sent: 1024, received: 2048)

      expect(stats.data_transferred[:sent]).to eq(1024)
      expect(stats.data_transferred[:received]).to eq(2048)
    end

    it 'накапливает данные при множественных вызовах' do
      stats = described_class.new
      stats.update_data_transfer(sent: 1024, received: 2048)
      stats.update_data_transfer(sent: 512, received: 1024)

      expect(stats.data_transferred[:sent]).to eq(1536)
      expect(stats.data_transferred[:received]).to eq(3072)
    end
  end

  describe '#reset_stats' do
    it 'сбрасывает всю статистику' do
      stats = described_class.new
      stats.connection_started
      stats.connection_successful
      stats.update_data_transfer(sent: 1024, received: 2048)

      stats.reset_stats

      expect(stats.total_connections).to eq(0)
      expect(stats.successful_connections).to eq(0)
      expect(stats.data_transferred[:sent]).to eq(0)
      expect(stats.data_transferred[:received]).to eq(0)
    end
  end

  describe '#format_uptime' do
    it 'форматирует время в читаемый вид' do
      stats = described_class.new

      expect(stats.format_uptime(0)).to eq('0с')
      expect(stats.format_uptime(59)).to eq('59с')
      expect(stats.format_uptime(60)).to eq('1м')
      expect(stats.format_uptime(3661)).to eq('1ч 1м 1с')
      expect(stats.format_uptime(86400)).to eq('1д')
      expect(stats.format_uptime(90061)).to eq('1д 1ч 1м 1с')
    end
  end

  describe '#format_bytes' do
    it 'форматирует байты в читаемый вид' do
      stats = described_class.new

      expect(stats.format_bytes(500)).to eq('500.0 B')
      expect(stats.format_bytes(1024)).to eq('1.0 KB')
      expect(stats.format_bytes(1536)).to eq('1.5 KB')
      expect(stats.format_bytes(1048576)).to eq('1.0 MB')
      expect(stats.format_bytes(1073741824)).to eq('1.0 GB')
    end
  end

  describe '#save_stats and #load_stats' do
    it 'сохраняет и загружает статистику из файла' do
      stats1 = described_class.new
      stats1.connection_started
      stats1.connection_successful
      stats1.update_data_transfer(sent: 1024, received: 2048)
      stats1.save_stats

      stats2 = described_class.new
      stats2.load_stats

      expect(stats2.total_connections).to eq(stats1.total_connections)
      expect(stats2.successful_connections).to eq(stats1.successful_connections)
      expect(stats2.data_transferred).to eq(stats1.data_transferred)
    end
  end
end
