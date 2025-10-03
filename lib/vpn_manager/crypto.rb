require 'openssl'
require 'base64'
require 'json'

module VPNManager
  class Crypto
    ALGORITHM = 'aes-256-gcm'
    KEY_LENGTH = 32
    IV_LENGTH = 12
    AUTH_TAG_LENGTH = 16

    class << self
      # Генерирует мастер-ключ из пароля пользователя
      def derive_key(password, salt)
        OpenSSL::PKCS5.pbkdf2_hmac(
          password,
          salt,
          100_000,
          KEY_LENGTH,
          OpenSSL::Digest::SHA256.new
        )
      end

      # Шифрует данные с использованием AES-256-GCM
      def encrypt(plaintext, password)
        salt = OpenSSL::Random.random_bytes(16)
        key = derive_key(password, salt)
        iv = OpenSSL::Random.random_bytes(IV_LENGTH)

        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv

        encrypted = cipher.update(plaintext) + cipher.final
        auth_tag = cipher.auth_tag

        # Объединяем salt + iv + auth_tag + зашифрованные данные
        result = salt + iv + auth_tag + encrypted
        Base64.strict_encode64(result)
      end

      # Расшифровывает данные
      def decrypt(ciphertext, password)
        data = Base64.strict_decode64(ciphertext)

        salt = data[0...16]
        iv = data[16...(16 + IV_LENGTH)]
        auth_tag = data[(16 + IV_LENGTH)...(16 + IV_LENGTH + AUTH_TAG_LENGTH)]
        encrypted = data[(16 + IV_LENGTH + AUTH_TAG_LENGTH)..-1]

        key = derive_key(password, salt)

        decipher = OpenSSL::Cipher.new(ALGORITHM)
        decipher.decrypt
        decipher.key = key
        decipher.iv = iv
        decipher.auth_tag = auth_tag

        decipher.update(encrypted) + decipher.final
      rescue OpenSSL::Cipher::CipherError
        raise "Неверный мастер-пароль или поврежденные данные"
      end

      # Сохраняет зашифрованные учетные данные
      def save_credentials(server, username, password, master_password)
        VPNManager.ensure_config_dir

        credentials = {
          server: server,
          username: username,
          password: password,
          created_at: Time.now.to_i
        }

        encrypted_data = encrypt(credentials.to_json, master_password)
        File.write(VPNManager::CREDENTIALS_FILE, encrypted_data, mode: 'w', perm: 0600)
      end

      # Загружает и расшифровывает учетные данные
      def load_credentials(master_password)
        unless File.exist?(VPNManager::CREDENTIALS_FILE)
          raise "Учетные данные не найдены. Используйте команду 'setup' для настройки."
        end

        encrypted_data = File.read(VPNManager::CREDENTIALS_FILE)
        decrypted = decrypt(encrypted_data, master_password)
        JSON.parse(decrypted, symbolize_names: true)
      end
    end
  end
end
