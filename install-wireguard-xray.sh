#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Установка WireGuard + XRay VPN${NC}"
echo -e "${GREEN}================================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Запустите с правами root${NC}" 
   exit 1
fi

# Параметры для настройки
read -p "Введите желаемое количество клиентов WireGuard (по умолчанию 5): " CLIENT_COUNT
CLIENT_COUNT=${CLIENT_COUNT:-5}

# Системные обновления
echo -e "${YELLOW}[1/9] Обновление системы...${NC}"
apt update && apt upgrade -y

# Установка пакетов
echo -e "${YELLOW}[2/9] Установка необходимых пакетов...${NC}"
apt install -y wireguard wireguard-tools curl wget qrencode ufw fail2ban

# Включение IP forwarding
echo -e "${YELLOW}[3/9] Включение IP forwarding...${NC}"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Генерация ключей сервера WireGuard
echo -e "${YELLOW}[4/9] Генерация ключей WireGuard...${NC}"
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Определение сетевого интерфейса
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Создание конфигурации сервера
echo -e "${YELLOW}[5/9] Создание конфигурации WireGuard...${NC}"
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.0.0.1/24
ListenPort = 51820
MTU = 1420
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_INTERFACE} -j MASQUERADE

EOF

# Генерация клиентских конфигураций
echo -e "${YELLOW}[6/9] Генерация клиентских конфигураций...${NC}"
mkdir -p /root/wireguard-clients
SERVER_IP=$(curl -s ifconfig.me)

for i in $(seq 1 $CLIENT_COUNT); do
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    CLIENT_IP="10.0.0.$((i+1))"
    
    # Добавление клиента в конфиг сервера
    cat >> /etc/wireguard/wg0.conf << EOF
# Client $i
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32

EOF

    # Создание клиентской конфигурации
    cat > /root/wireguard-clients/client${i}.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    # Генерация QR-кода для мобильных устройств
    qrencode -t ansiutf8 < /root/wireguard-clients/client${i}.conf > /root/wireguard-clients/client${i}-qr.txt
    
    echo -e "${GREEN}  ✓ Создан клиент ${i}${NC}"
done

# Запуск WireGuard
echo -e "${YELLOW}[7/9] Запуск WireGuard...${NC}"
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Установка XRay
echo -e "${YELLOW}[8/9] Установка XRay для обфускации...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Генерация UUID и ключей для XRay
XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
XRAY_KEYS=$(xray x25519)
XRAY_PRIVATE_KEY=$(echo "$XRAY_KEYS" | grep "Private key" | awk '{print $3}')
XRAY_PUBLIC_KEY=$(echo "$XRAY_KEYS" | grep "Public key" | awk '{print $3}')

# Создание директории для логов
mkdir -p /var/log/xray

# Создание правильной конфигурации XRay
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "${XRAY_UUID}",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.microsoft.com:443",
        "xver": 0,
        "serverNames": [
          "www.microsoft.com",
          "www.bing.com"
        ],
        "privateKey": "${XRAY_PRIVATE_KEY}",
        "shortIds": ["", "0123456789abcdef"]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "tag": "direct"
  }]
}
EOF

# Проверка валидности конфигурации
if ! xray -test -config=/usr/local/etc/xray/config.json; then
    echo -e "${RED}ОШИБКА: Конфигурация XRay невалидна!${NC}"
    cat /usr/local/etc/xray/config.json
    exit 1
fi

# Запуск XRay
systemctl enable xray
systemctl start xray

# Проверка запуска
sleep 2
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✓ XRay запущен успешно${NC}"
else
    echo -e "${RED}✗ XRay не запустился!${NC}"
    journalctl -u xray -n 20
    exit 1
fi

# Настройка Firewall
echo -e "${YELLOW}[9/9] Настройка firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 51820/udp comment 'WireGuard'
ufw allow 443/tcp comment 'XRay'
ufw --force enable

# Финальный вывод
SERVER_IP=$(curl -s ifconfig.me)

cat > /root/vpn-info.txt << EOF
╔════════════════════════════════════════════════════════════╗
║           VPN СЕРВЕР УСПЕШНО УСТАНОВЛЕН                    ║
╚════════════════════════════════════════════════════════════╝

SERVER IP: ${SERVER_IP}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WIREGUARD (максимальная скорость)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Порт: 51820 (UDP)
Клиентов создано: ${CLIENT_COUNT}
Конфигурации: /root/wireguard-clients/

Команды управления:
  systemctl status wg-quick@wg0    # статус
  wg show                          # активные соединения
  journalctl -u wg-quick@wg0 -f    # логи

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XRAY VLESS (защита от блокировок)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Порт: 443 (TCP)
UUID: ${XRAY_UUID}
Протокол: VLESS + XTLS-Reality

Строка подключения:
vless://${XRAY_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${XRAY_PUBLIC_KEY}&type=tcp#MyVPN

Команды управления:
  systemctl status xray            # статус
  journalctl -u xray -f            # логи

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
КЛИЕНТСКИЕ ПРИЛОЖЕНИЯ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WireGuard:
  • Windows/macOS/Linux: https://www.wireguard.com/install/
  • Android: WireGuard (Google Play)
  • iOS: WireGuard (App Store)

XRay:
  • Windows: v2rayN
  • Android: v2rayNG
  • iOS: Shadowrocket

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
МОНИТОРИНГ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  htop                  # загрузка системы
  nethogs               # сетевой трафик
  ufw status            # статус firewall
  fail2ban-client status # защита от брутфорса

Установлено: $(date)
╚════════════════════════════════════════════════════════════╝
EOF

cat /root/vpn-info.txt

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Клиентские конфигурации WireGuard:${NC}"
echo -e "${GREEN}  /root/wireguard-clients/${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Для просмотра QR-кода клиента:${NC}"
echo "cat /root/wireguard-clients/client1-qr.txt"
