Here is a step-by-step guide to setting up a Matrix Dendrite server on your local Windows machine using Docker Compose. This process will walk you from the initial setup to the moment you log in with a Matrix client.

The setup involves three main stages: generating security keys, configuring the server, and launching the containers.

🐳 Step 1: Generate Private Key and Config
First, open PowerShell or Command Prompt and create a dedicated project folder. Navigate into it and run the following commands.

1. Generate the Signing Key
This key is crucial for signing events and identifying your server.

powershell
mkdir -p ./config
docker run --rm --entrypoint="/usr/bin/generate-keys" -v ${PWD}/config:/mnt matrixdotorg/dendrite-monolith:latest -private-key /mnt/matrix_key.pem
Note: If you are using Command Prompt (cmd), replace ${PWD} with %cd%.

2. Generate the Configuration File
This creates a base dendrite.yaml file. Crucially, you must replace your.domain.com with your actual server name (for a local network test, you can use a name like matrix.local or your computer's hostname).

powershell
docker run --rm --entrypoint="/bin/sh" -v ${PWD}/config:/mnt matrixdotorg/dendrite-monolith:latest -c "/usr/bin/generate-config -dir /var/dendrite/ -db postgres://dendrite:itsasecret@postgres/dendrite?sslmode=disable -server your.domain.com > /mnt/dendrite.yaml"
🐳 Step 2: Create the Docker Compose File
In your project folder, create a file named docker-compose.yml. Copy and paste the following configuration. This defines the Dendrite server and its PostgreSQL database.

yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    container_name: dendrite_db
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

  monolith:
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

networks:
  dendrite_network:
🐳 Step 3: Run and Register Your User
1. Launch the Server
From your project folder in the terminal, run:

bash
docker-compose up -d
This will download the images and start the containers in the background. You can check the logs with docker-compose logs -f to ensure there are no errors.

2. Create Your Admin Account
Your server is now running but has no users. You need to create one using the registration secret we set in the config. Run this command to create an admin user named your-username:

bash
docker exec -it dendrite_server /usr/bin/create-account \
  -config /etc/dendrite/dendrite.yaml \
  -username your-username \
  -password a-strong-password \
  -admin
🐳 Step 4: Connect with a Client
Your local Dendrite server is now running and listening on your Windows machine.

Server URL: In your Matrix client, set the Homeserver URL to http://localhost:8008.

Login: Use the username (your-username) and password you just created.

Client Recommendation: You can use any Matrix client, but Element Web is a common choice. You can either use the public version at app.element.io (just change the server URL in the login settings) or run it locally via Docker.

🚀 Next Steps & Local Networking
Access from other devices: To connect from your phone or another computer on your local network, replace localhost with your Windows machine's local IP address (e.g., http://192.168.1.100:8008). You might need to adjust your Windows Firewall to allow incoming connections on ports 8008 and 8448.

Federation: If you want to chat with users on other Matrix servers (like matrix.org), your server needs to be publicly accessible on the internet and configured with a valid domain name and SSL certificates. This guide focuses on a local setup, which is perfect for testing and learning.

I hope this guide helps you get your server running smoothly. Are you planning to connect from other devices on your network, or will this just be for local testing?

🎨 Recommended: Add Element Web via Docker Compose
Update your docker-compose.yml file to include Element Web as an additional service:

yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    container_name: dendrite_db
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

  monolith:
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

  # 👇 ADD ELEMENT WEB SERVICE
  element-web:
    image: vectorim/element-web:latest
    container_name: element_web
    ports:
      - "8080:80"  # Access Element Web at http://localhost:8080
    volumes:
      - ./element-config.json:/app/config.json:ro
    depends_on:
      - monolith
    networks:
      - dendrite_network
    restart: unless-stopped

networks:
  dendrite_network:
📝 Step 2: Create Element Web Configuration
Create an element-config.json file in your project folder (same directory as docker-compose.yml):

json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "http://monolith:8008",
      "server_name": "your.domain.com"
    },
    "m.identity_server": {
      "base_url": "https://vector.im"
    }
  },
  "brand": "Element",
  "integrations_ui_url": "https://scalar.vector.im/",
  "integrations_rest_url": "https://scalar.vector.im/api",
  "integrations_widgets_urls": [
    "https://scalar.vector.im/_matrix/integrations/v1",
    "https://scalar.vector.im/api",
    "https://scalar-staging.vector.im/_matrix/integrations/v1",
    "https://scalar-staging.vector.im/api"
  ],
  "default_country_code": "GB",
  "show_labs_settings": true,
  "features": {
    "feature_pinning": true,
    "feature_custom_status": true,
    "feature_message_forwarding": true
  },
  "room_directory": {
    "servers": ["matrix.org", "your.domain.com"]
  },
  "enable_presence_by_hs_url": {
    "http://monolith:8008": true
  }
}
Important: Replace your.domain.com with your actual server name (same one you used when generating dendrite.yaml).

🚀 Step 3: Launch Everything
bash
# Stop any running containers
docker-compose down

# Start everything (Dendrite + Element Web)
docker-compose up -d

# Check logs to ensure everything is running
docker-compose logs -f
🔗 Step 4: Access Element Web
Once everything is running:

Open your browser and navigate to: http://localhost:8080

Sign in using:

Homeserver URL: http://localhost:8008 (or leave blank if configured properly)

Username: your-username (the one you created earlier)

Password: your-password

📞 Архитектура звонков в Matrix
Современный стек звонков в Matrix (Native MatrixRTC) больше не использует P2P-подключения. Он построен на архитектуре SFU (Selective Forwarding Unit) и требует нескольких компонентов :

LiveKit — SFU-сервер, который принимает видеопотоки от участников и пересылает их другим

lk-jwt-service — сервис-мост, который выдает токены доступа к LiveKit для пользователей Matrix

Element Call — специализированный интерфейс для групповых звонков (может работать внутри Element Web)

CoTurn — TURN/STUN-сервер для обхода NAT и файерволов

🐳 Docker Compose конфигурация
Ниже представлен полный docker-compose.yml с добавлением всех необходимых сервисов. Обратите внимание: этот конфиг предназначен для production-окружения и требует публичного домена с валидным SSL-сертификатом. Локальная отладка звонков (через localhost) может не работать из-за требований WebRTC к HTTPS .

yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    container_name: dendrite_db
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

  # ========== НОВЫЕ СЕРВИСЫ ДЛЯ ЗВОНКОВ ==========

  redis:
    image: redis:7-alpine
    container_name: dendrite_redis
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - ./redis_data:/data
    networks:
      - dendrite_network
    restart: unless-stopped

  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit_server
    command: --config /etc/livekit.yaml
    ports:
      - "7881:7881"                     # TCP Signaling
      - "7882:7882/udp"                 # UDP media
      - "50000-50200:50000-50200/udp"   # Media port range
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
    environment:
      - LIVEKIT_KEYS=api_key:${LIVEKIT_SECRET}
    depends_on:
      - redis
    networks:
      - dendrite_network
    restart: unless-stopped

  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    container_name: lk_jwt_service
    environment:
      - LIVEKIT_URL=wss://livekit.${DOMAIN}
      - LIVEKIT_KEY=api_key
      - LIVEKIT_SECRET=${LIVEKIT_SECRET}
      - MATRIX_SERVER_URL=http://dendrite:8008
    networks:
      - dendrite_network
    restart: unless-stopped

  element-call:
    image: ghcr.io/element-hq/element-call:latest
    container_name: element_call
    ports:
      - "8081:80"
    volumes:
      - ./element-call-config.json:/app/config.json:ro
    depends_on:
      - lk-jwt-service
    networks:
      - dendrite_network
    restart: unless-stopped

  coturn:
    image: coturn/coturn:latest
    container_name: turn_server
    network_mode: host
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf:ro
      - ./certs:/etc/coturn/certs:ro
    restart: unless-stopped

networks:
  dendrite_network:
⚙️ Конфигурационные файлы
1. livekit.yaml
yaml
port: 7880
rtc:
  udp_port: 7882
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50200
  use_external_ip: true
  turn_servers:
    - host: turn.${DOMAIN}
      port: 3478
      protocol: udp
      secret: ${TURN_SECRET}
redis:
  address: redis:6379
keys:
  api_key: ${LIVEKIT_SECRET}
2. turnserver.conf
conf
listening-port=3478
tls-listening-port=5349
min-port=49152
max-port=65535
external-ip=${PUBLIC_IP}
realm=turn.${DOMAIN}
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=${TURN_SECRET}
no-multicast-peers
no-cli
3. element-call-config.json
json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "http://localhost:8008",
      "server_name": "localhost"
    }
  },
  "livekit": {
    "livekit_service_url": "http://localhost:8081"
  },
  "features": {
    "feature_group_calls": true
  }
}
🚀 Переменные окружения (файл .env)
bash
DOMAIN=your.domain.com
PUBLIC_IP=your_server_public_ip
LIVEKIT_SECRET=generate_strong_random_string
TURN_SECRET=generate_another_strong_random_string
🔧 Настройка Dendrite
В dendrite.yaml добавьте конфигурацию TURN-сервера:

yaml
turn:
  turn_uris:
    - "turn:turn.${DOMAIN}:3478?transport=udp"
    - "turn:turn.${DOMAIN}:3478?transport=tcp"
  turn_shared_secret: "${TURN_SECRET}"
⚠️ Важные ограничения и troubleshooting
Dendrite и звонки: Пользователи сообщают о проблемах с инициализацией звонков в Dendrite . Кнопки звонков могут не реагировать, а в логах могут быть ошибки 404 на эндпоинтах /_matrix/client/r0/thirdparty/user/ .

Проблема "Waiting for media": Часто возникает из-за того, что LiveKit не видит правильный внешний IP. Убедитесь, что use_external_ip: true в livekit.yaml и порты UDP проброшены правильно .

HTTPS обязателен: WebRTC требует безопасного контекста. Для локальной разработки придется использовать self-signed сертификаты и вручную добавить их в доверенные .

Проблемы с TURN: Если звонки работают только при включенном turn.matrix.org, значит ваш TURN-сервер настроен неверно. Проверьте файрвол и конфигурацию .

Медиа порты: Убедитесь, что следующие порты открыты в брандмауэре Windows:

7881 TCP

7882 UDP

50000-50200 UDP

3478 UDP/TCP

49152-65535 UDP (для TURN)