# Matrix Dendrite Server for Corporate Local Network

Полное решение для развертывания защищенного корпоративного мессенджера Matrix Dendrite с Element Web в локальной сети.

## 📋 Оглавление

- [Архитектура](#-архитектура)
- [Требования](#-требования)
- [Быстрый старт](#-быстрый-старт)
- [Конфигурация](#-конфигурация)
- [Управление пользователями](#-управление-пользователями)
- [Запуск и остановка](#-запуск-и-остановка)
- [Устранение неполадок](#-устранение-неполадок)
- [Безопасность](#-безопасность)
- [Производительность](#-производительность)

## 🏗 Архитектура
┌─────────────────────────────────────────────────────────┐
│ Docker Compose │
├─────────────────────────────────────────────────────────┤
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Dendrite │ │ PostgreSQL │ │ Element Web │ │
│ │ (Matrix) │ │ (Database) │ │ (Client) │ │
│ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ │
│ │ │ │ │
│ └──────────────────┴──────────────────┘ │
│ │ │
│ Network: bridge │
└─────────────────────────┼───────────────────────────────┘
│
┌─────┴─────┐
│ LAN Users │
└───────────┘

text

## 💻 Требования

- **Windows 10/11** или **Windows Server 2019/2022**
- **Docker Desktop** (с поддержкой WSL2)
- **8 GB RAM** (рекомендуется)
- **20 GB свободного дискового пространства**
- **PowerShell 5.1+**

## 🚀 Быстрый старт

### 1. Установка Docker Desktop

Скачайте и установите [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).
После установки включите WSL2 интеграцию.

### 2. Клонирование проекта

powershell
# Создайте директорию проекта
mkdir C:\Projects\matrix_docker
cd C:\Projects\matrix_docker

# Создайте необходимые директории
mkdir config, media, postgresql
3. Генерация ключей и конфигурации
powershell
# Генерация signing key
docker run --rm --entrypoint="/usr/bin/generate-keys" -v ${PWD}/config:/mnt matrixdotorg/dendrite-monolith:latest -private-key /mnt/matrix_key.pem

# Генерация конфигурации (замените matrix.corp.local на ваш адрес)
docker run --rm --entrypoint="/bin/sh" -v ${PWD}/config:/mnt matrixdotorg/dendrite-monolith:latest -c "/usr/bin/generate-config -dir /var/dendrite/ -db postgres://dendrite:itsasecret@postgres/dendrite?sslmode=disable -server matrix.corp.local > /mnt/dendrite.yaml"
4. Настройка Docker Compose
Создайте docker-compose.yml:

yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: dendrite_db
    restart: unless-stopped
    volumes:
      - ./postgresql:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: itsasecret
      POSTGRES_USER: dendrite
      POSTGRES_DB: dendrite
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dendrite"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - dendrite_network

  dendrite:
    image: matrixdotorg/dendrite-monolith:latest
    container_name: dendrite_server
    ports:
      - "8008:8008"
      - "8448:8448"
    volumes:
      - ./config:/etc/dendrite
      - ./media:/var/dendrite/media
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - dendrite_network
    restart: unless-stopped

  element-web:
    image: vectorim/element-web:latest
    container_name: element_web
    ports:
      - "8080:80"
    volumes:
      - ./element-config.json:/app/config.json:ro
    depends_on:
      - dendrite
    networks:
      - dendrite_network
    restart: unless-stopped

networks:
  dendrite_network:
5. Настройка Element Web
Создайте element-config.json:

json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "http://dendrite:8008",
      "server_name": "matrix.corp.local"
    }
  },
  "brand": "Element",
  "show_labs_settings": true,
  "features": {
    "feature_pinning": true,
    "feature_custom_status": true
  }
}
6. Запуск сервера
powershell
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f
⚙️ Конфигурация
Основные настройки dendrite.yaml
yaml
global:
  # Имя сервера (важно для локальной сети)
  server_name: matrix.corp.local
  
  # Отключаем федерацию для корпоративной сети
  disable_federation: true
  
  # Настройки базы данных
  database:
    connection_string: postgresql://dendrite:itsasecret@postgres/dendrite?sslmode=disable
    max_open_conns: 90
    max_idle_conns: 5

client_api:
  # Отключаем открытую регистрацию
  registration_disabled: true
  # Включаем регистрацию по shared secret
  registration_shared_secret: "YOUR_SECRET_KEY_HERE"

media_api:
  # Максимальный размер загружаемых файлов (100MB)
  max_file_size_bytes: 104857600
Переменные окружения
Создайте .env файл для sensitive данных:

env
POSTGRES_PASSWORD=itsasecret
SHARED_SECRET=your_strong_secret_key_here
DOMAIN=matrix.corp.local
👥 Управление пользователями
Создание администратора
powershell
docker exec -it dendrite_server /usr/bin/create-account `
  -config /etc/dendrite/dendrite.yaml `
  -username admin -admin
Массовое создание пользователей (PowerShell скрипт)
Создайте create_users.ps1:

powershell
# create_users.ps1
$SHARED_SECRET = "YOUR_SECRET_KEY_HERE"
$SERVER_URL = "http://localhost:8008"

$users = @(
    @{username="ivanov"; password="Pass123!"; admin=$false},
    @{username="petrov"; password="Pass456!"; admin=$false},
    @{username="sidorov"; password="Pass789!"; admin=$true}
)

function Create-User {
    param($Username, $Password, $IsAdmin)
    
    $nonce = ([DateTimeOffset]::Now.ToUnixTimeMilliseconds()).ToString()
    $adminFlag = if ($IsAdmin) { "admin" } else { "notadmin" }
    
    $macString = "$nonce`0$Username`0$Password`0$adminFlag"
    $hmac = New-Object System.Security.Cryptography.HMACSHA1
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($SHARED_SECRET)
    $signature = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($macString))
    $mac = [Convert]::ToBase64String($signature)
    
    $body = @{
        nonce = $nonce
        username = $Username
        password = $Password
        mac = $mac
        admin = $IsAdmin
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$SERVER_URL/_matrix/client/r0/register" `
            -Method Post -Body $body -ContentType "application/json"
        Write-Host "✓ Created $Username" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to create $Username" -ForegroundColor Red
    }
}

foreach ($user in $users) {
    Create-User -Username $user.username -Password $user.password -IsAdmin $user.admin
    Start-Sleep -Seconds 1
}
🔄 Запуск и остановка
Базовые команды
powershell
# Запуск всех сервисов
docker-compose up -d

# Остановка всех сервисов
docker-compose down

# Перезапуск
docker-compose restart

# Просмотр статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f dendrite

# Остановка с удалением томов (очистка данных)
docker-compose down -v
Обновление сервера
powershell
# Скачать новые образы
docker-compose pull

# Пересоздать контейнеры с новыми образами
docker-compose up -d --force-recreate
🔧 Устранение неполадок
Конфликт имен контейнеров
powershell
# Остановить и удалить старые контейнеры
docker-compose down
docker rm dendrite_server
docker-compose up -d
Ошибка "inappropriate ioctl for device"
Используйте API метод создания пользователей вместо create-account.

Проблемы с подключением клиентов
Проверьте:

Доступность порта 8008: Test-NetConnection -ComputerName localhost -Port 8008

Настройки брандмауэра Windows

Правильность server_name в конфигурации клиента

Логирование ошибок
powershell
# Детальные логи Dendrite
docker-compose logs --tail=100 dendrite

# Логи PostgreSQL
docker-compose logs postgres

# Логи Element Web
docker-compose logs element-web
🔒 Безопасность
Рекомендации для корпоративной сети
Используйте сложные пароли для всех учетных записей

Регулярно меняйте registration_shared_secret

Ограничьте доступ к портам через брандмауэр Windows

Ведите аудит созданных пользователей

Настройте регулярные бэкапы базы данных

Бэкап данных
powershell
# Бэкап PostgreSQL
docker exec dendrite_db pg_dump -U dendrite dendrite > backup_$(Get-Date -Format "yyyyMMdd").sql

# Бэкап конфигурации
Copy-Item -Path .\config -Destination .\backup_config_$(Get-Date -Format "yyyyMMdd") -Recurse

# Бэкап медиафайлов
Copy-Item -Path .\media -Destination .\backup_media_$(Get-Date -Format "yyyyMMdd") -Recurse
⚡ Производительность
Оптимизация для корпоративной сети
Увеличьте лимиты в Docker Desktop:

CPU: 4 ядра

RAM: 4 GB

Swap: 1 GB

Настройки PostgreSQL в docker-compose.yml:

yaml
command: >
  postgres -c shared_buffers=256MB
           -c effective_cache_size=768MB
           -c maintenance_work_mem=64MB
Мониторинг ресурсов:

powershell
docker stats
📱 Подключение клиентов
Element Web
URL: http://YOUR_SERVER_IP:8080

Homeserver URL: http://YOUR_SERVER_IP:8008

Другие клиенты
Element Desktop: Настройки → Изменить сервер → http://YOUR_SERVER_IP:8008

FluffyChat: Настройки → Добавить домашний сервер → http://YOUR_SERVER_IP:8008

🗺 План развития
Добавить голосовые и видеозвонки (LiveKit + Element Call)

Настроить резервное копирование

Интеграция с Active Directory

Веб-интерфейс администратора

Автоматическое создание комнат для отделов

📞 Поддержка
Matrix Documentation: https://matrix.org/docs/

Dendrite Docs: https://matrix-org.github.io/dendrite/

Docker Docs: https://docs.docker.com/

📄 Лицензия
Этот проект использует компоненты с открытым исходным кодом. Dendrite лицензирован под Apache 2.0.

⚠️ Важно: Dendrite более не поддерживается официально (архивирован 25 ноября 2024). Для production-использования рекомендуется рассмотреть миграцию на Synapse.

Последнее обновление: 2026-04-10



# Этот README включает все необходимые инструкции для развертывания и управления вашим Matrix сервером в локальной корпоративной сети. Вы можете адаптировать его под свои конкретные требования!
