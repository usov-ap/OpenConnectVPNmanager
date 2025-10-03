# Быстрый старт

## Установка

```bash
cd OpenConnectVPNmanager
bundle install
```

## Первоначальная настройка

```bash
./bin/vpnctl setup
```

Введите:
- Адрес сервера (например: vpn.company.com)
- Имя пользователя
- Пароль VPN
- Мастер-пароль (минимум 8 символов) - будет использоваться для шифрования

## Основные команды

### Запуск VPN
```bash
./bin/vpnctl start
```

С автоматическим переподключением:
```bash
./bin/vpnctl start -r
```

### Проверка статуса
```bash
./bin/vpnctl status
```

### Просмотр статистики
```bash
./bin/vpnctl stats
```

### Остановка VPN
```bash
./bin/vpnctl stop
```

### Просмотр логов
```bash
./bin/vpnctl logs -n 50
```

## Запуск тестов

```bash
bundle exec rspec
```

## Структура проекта

```
OpenConnectVPNmanager/
├── bin/
│   └── vpnctl              # Исполняемый CLI
├── lib/
│   └── vpn_manager/
│       ├── crypto.rb       # AES-256-GCM шифрование
│       ├── connection.rb   # Управление VPN
│       ├── logger.rb       # Логирование
│       ├── statistics.rb   # Метрики и статистика
│       └── cli.rb          # CLI интерфейс
├── spec/                   # Тесты (44 примера)
└── README.md               # Полная документация
```

## Файлы конфигурации

Все данные хранятся в `~/.vpn_manager/`:
- `credentials.enc` - зашифрованные учетные данные (AES-256-GCM)
- `stats.json` - статистика использования
- `vpn.log` - лог файл
- `vpn.pid` - PID активного соединения

## Требования

- Ruby 2.7+
- OpenConnect VPN клиент
- Права sudo (для запуска OpenConnect)
