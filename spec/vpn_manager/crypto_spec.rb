require 'spec_helper'
require 'tempfile'

RSpec.describe VPNManager::Crypto do
  let(:password) { 'test_master_password_123' }
  let(:plaintext) { 'sensitive data' }

  describe '.derive_key' do
    it 'генерирует ключ нужной длины' do
      salt = OpenSSL::Random.random_bytes(16)
      key = described_class.derive_key(password, salt)

      expect(key.length).to eq(VPNManager::Crypto::KEY_LENGTH)
    end

    it 'генерирует одинаковые ключи для одинаковых входных данных' do
      salt = OpenSSL::Random.random_bytes(16)
      key1 = described_class.derive_key(password, salt)
      key2 = described_class.derive_key(password, salt)

      expect(key1).to eq(key2)
    end

    it 'генерирует разные ключи для разных паролей' do
      salt = OpenSSL::Random.random_bytes(16)
      key1 = described_class.derive_key('password1', salt)
      key2 = described_class.derive_key('password2', salt)

      expect(key1).not_to eq(key2)
    end
  end

  describe '.encrypt and .decrypt' do
    it 'шифрует и расшифровывает данные корректно' do
      encrypted = described_class.encrypt(plaintext, password)
      decrypted = described_class.decrypt(encrypted, password)

      expect(decrypted).to eq(plaintext)
    end

    it 'возвращает разные зашифрованные данные при каждом вызове' do
      encrypted1 = described_class.encrypt(plaintext, password)
      encrypted2 = described_class.encrypt(plaintext, password)

      expect(encrypted1).not_to eq(encrypted2)
    end

    it 'выбрасывает ошибку при неверном пароле' do
      encrypted = described_class.encrypt(plaintext, password)

      expect {
        described_class.decrypt(encrypted, 'wrong_password')
      }.to raise_error(RuntimeError, /Неверный мастер-пароль/)
    end

    it 'выбрасывает ошибку при поврежденных данных' do
      encrypted = described_class.encrypt(plaintext, password)
      corrupted = encrypted[0...-5] + 'xxxxx'

      expect {
        described_class.decrypt(corrupted, password)
      }.to raise_error(RuntimeError)
    end
  end

  describe '.save_credentials and .load_credentials' do
    let(:server) { 'vpn.example.com' }
    let(:username) { 'testuser' }
    let(:vpn_password) { 'vpn_pass_123' }
    let(:temp_dir) { Dir.mktmpdir }

    before do
      stub_const('VPNManager::CONFIG_DIR', temp_dir)
      stub_const('VPNManager::CREDENTIALS_FILE', File.join(temp_dir, 'credentials.enc'))
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'сохраняет и загружает учетные данные' do
      described_class.save_credentials(server, username, vpn_password, password)

      credentials = described_class.load_credentials(password)

      expect(credentials[:server]).to eq(server)
      expect(credentials[:username]).to eq(username)
      expect(credentials[:password]).to eq(vpn_password)
      expect(credentials[:created_at]).to be_a(Integer)
    end

    it 'выбрасывает ошибку, если файл не существует' do
      expect {
        described_class.load_credentials(password)
      }.to raise_error(RuntimeError, /Учетные данные не найдены/)
    end

    it 'создает файл с правами доступа 0600' do
      described_class.save_credentials(server, username, vpn_password, password)

      file_stat = File.stat(VPNManager::CREDENTIALS_FILE)
      expect(file_stat.mode & 0777).to eq(0600)
    end
  end
end
