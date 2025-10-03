require 'spec_helper'
require 'tempfile'

RSpec.describe VPNManager::VPNLogger do
  let(:temp_dir) { Dir.mktmpdir }
  let(:log_file) { File.join(temp_dir, 'vpn.log') }

  before do
    stub_const('VPNManager::CONFIG_DIR', temp_dir)
    stub_const('VPNManager::LOG_FILE', log_file)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '#initialize' do
    it 'создает лог-файл' do
      logger = described_class.new
      logger.info('test')

      expect(File.exist?(log_file)).to be true
    end
  end

  describe '#info' do
    it 'записывает INFO сообщение' do
      logger = described_class.new
      logger.info('test message')

      content = File.read(log_file)
      expect(content).to include('INFO')
      expect(content).to include('test message')
    end
  end

  describe '#error' do
    it 'записывает ERROR сообщение' do
      logger = described_class.new
      logger.error('error message')

      content = File.read(log_file)
      expect(content).to include('ERROR')
      expect(content).to include('error message')
    end
  end

  describe '#warn' do
    it 'записывает WARN сообщение' do
      logger = described_class.new
      logger.warn('warning message')

      content = File.read(log_file)
      expect(content).to include('WARN')
      expect(content).to include('warning message')
    end
  end

  describe '#tail' do
    it 'возвращает последние N строк' do
      logger = described_class.new

      5.times { |i| logger.info("message #{i}") }

      lines = logger.tail(3)
      expect(lines.length).to eq(3)
      expect(lines.last).to include('message 4')
    end

    it 'возвращает только заголовок, если лог пустой' do
      logger = described_class.new
      lines = logger.tail

      expect(lines.length).to eq(1)
      expect(lines.first).to include('Logfile created')
    end
  end
end
