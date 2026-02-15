#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ПОЛНАЯ УСТАНОВКА VPN СЕРВЕРА                          ║
║     WireGuard + XRay + Shadowsocks + Monitoring           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Требуются права root${NC}" 
   exit 1
fi

# Функция валидации числа
validate_number() {
    local num=$1
    local min=$2
    local max=$3
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt "$min" ] || [ "$num" -gt "$max" ]; then
        echo -e "${RED}Ошибка: введите число от $min до $max${NC}"
        return 1
    fi
    return 0
}

# Интерактивная настройка с валидацией
echo -e "${YELLOW}Настройка параметров:${NC}"

while true; do
    read -p "Количество WireGuard клиентов [5]: " WG_CLIENTS
    WG_CLIENTS=${WG_CLIENTS:-5}
    if validate_number "$WG_CLIENTS" 1 100; then
        break
    fi
done

read -p "Пароль для Shadowsocks (генерировать автоматически? y/n) [y]: " SS_AUTO
SS_AUTO=${SS_AUTO:-y}

if [[ $SS_AUTO == "n" ]]; then
    while true; do
        read -sp "Введите пароль Shadowsocks (минимум 8 символов): " SS_PASSWORD
        echo ""
        if [ ${#SS_PASSWORD} -ge 8 ]; then
            break
        else
            echo -e "${RED}Пароль должен содержать минимум 8 символов${NC}"
        fi
    done
else
    SS_PASSWORD=$(openssl rand -base64 16)
fi

# Функция проверки выполнения команды
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}ОШИБКА: $1${NC}"
        exit 1
    fi
}

# Установка компонентов
echo -e "${YELLOW}[1/12] Обновление системы...${NC}"
apt update && apt upgrade -y
check_command "Не удалось обновить систему"

echo -e "${YELLOW}[2/12] Установка базовых пакетов...${NC}"
apt install -y curl wget git nano ufw fail2ban unattended-upgrades \
               htop iotop nethogs qrencode jq

echo -e "${YELLOW}[3/12] Установка WireGuard...${NC}"
apt install -y wireguard wireguard-tools

echo -e "${YELLOW}[4/12] Установка Shadowsocks...${NC}"
apt install -y shadowsocks-libev simple-obfs

echo -e "${YELLOW}[5/12] Оптимизация ядра...${NC}"
cat > /etc/sysctl.d/99-vpn-optimization.conf << EOF
# IP Forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# TCP BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Buffer Optimization
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Connection Optimization
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF

sysctl -p /etc/sysctl.d/99-vpn-optimization.conf

echo -e "${YELLOW}[6/12] Настройка WireGuard...${NC}"

# Включение IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Генерация ключей сервера WireGuard
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Определение сетевого интерфейса
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Создание конфигурации сервера
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
mkdir -p /root/wireguard-clients
SERVER_IP=$(curl -s ifconfig.me)

for i in $(seq 1 $WG_CLIENTS); do
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
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo -e "${YELLOW}[7/12] Установка XRay...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
XRAY_KEYS="$(xray x25519)"
XRAY_PRIVATE_KEY="$(echo "$XRAY_KEYS" | grep -E "Private key" | awk '{print $3}')"
XRAY_PUBLIC_KEY="$(echo "$XRAY_KEYS" | grep -E "Public key" | awk '{print $3}')"

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
        "flow": "xtls-rprx-vision",
        "email": "user1@vpn"
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
        "shortIds": [
          "",
          "0123456789abcdef"
        ]
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls"]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "tag": "direct"
  }, {
    "protocol": "blackhole",
    "tag": "block"
  }],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [{
      "type": "field",
      "ip": ["geoip:private"],
      "outboundTag": "block"
    }]
  }
}
EOF

mkdir -p /var/log/xray
if ! xray -test -config=/usr/local/etc/xray/config.json; then
    echo -e "${RED}ОШИБКА: Конфигурация XRay невалидна!${NC}"
    cat /usr/local/etc/xray/config.json
    exit 1
fi
systemctl enable xray
systemctl start xray

echo -e "${YELLOW}[8/12] Настройка Shadowsocks...${NC}"
cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "0.0.0.0",
    "server_port": 8388,
    "password": "${SS_PASSWORD}",
    "timeout": 300,
    "method": "chacha20-ietf-poly1305",
    "fast_open": true,
    "mode": "tcp_and_udp",
    "plugin": "obfs-server",
    "plugin_opts": "obfs=tls"
}
EOF

systemctl enable shadowsocks-libev
systemctl restart shadowsocks-libev

echo -e "${YELLOW}[9/12] Настройка Firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 51820/udp comment 'WireGuard'
ufw allow 443/tcp comment 'XRay VLESS'
ufw allow 8388/tcp comment 'Shadowsocks'
ufw allow 8388/udp comment 'Shadowsocks UDP'
ufw --force enable

echo -e "${YELLOW}[10/12] Настройка Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${YELLOW}[11/12] Создание скриптов мониторинга...${NC}"

# Скрипт проверки статуса
cat > /usr/local/bin/vpn-status << 'EOFSTATUS'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        VPN SERVER STATUS                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# WireGuard Status
echo -e "${YELLOW}WireGuard:${NC}"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "  Status: ${GREEN}● Active${NC}"
    PEERS=$(wg show wg0 peers | wc -l)
    echo -e "  Connected: ${GREEN}${PEERS} clients${NC}"
else
    echo -e "  Status: ${RED}● Inactive${NC}"
fi
echo ""

# XRay Status
echo -e "${YELLOW}XRay:${NC}"
if systemctl is-active --quiet xray; then
    echo -e "  Status: ${GREEN}● Active${NC}"
    PORT=$(ss -tlnp | grep xray | awk '{print $4}' | cut -d':' -f2 | head -1)
    echo -e "  Port: ${GREEN}${PORT}${NC}"
else
    echo -e "  Status: ${RED}● Inactive${NC}"
fi
echo ""

# Shadowsocks Status
echo -e "${YELLOW}Shadowsocks:${NC}"
if systemctl is-active --quiet shadowsocks-libev; then
    echo -e "  Status: ${GREEN}● Active${NC}"
else
    echo -e "  Status: ${RED}● Inactive${NC}"
fi
echo ""

# System Resources
echo -e "${YELLOW}System Resources:${NC}"
echo -e "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo -e "  RAM: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo -e "  Disk: $(df -h / | awk 'NR==2{print $5}')"
echo ""

# Network
echo -e "${YELLOW}Network:${NC}"
PRIMARY_INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
RX=$(cat /sys/class/net/${PRIMARY_INTERFACE}/statistics/rx_bytes 2>/dev/null || echo 0)
TX=$(cat /sys/class/net/${PRIMARY_INTERFACE}/statistics/tx_bytes 2>/dev/null || echo 0)
echo -e "  RX: $(numfmt --to=iec-i --suffix=B $RX)"
echo -e "  TX: $(numfmt --to=iec-i --suffix=B $TX)"
EOFSTATUS

chmod +x /usr/local/bin/vpn-status

# Скрипт добавления WireGuard клиента
cat > /usr/local/bin/wg-add-client << 'EOFWGADD'
#!/bin/bash
# Скрипт добавления нового клиента WireGuard

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Запустите с правами root${NC}"
    exit 1
fi

# Параметры
CLIENT_NAME=${1:-"client$(date +%s)"}
CLIENT_DIR="/root/wireguard-clients"

# Проверка существования клиента
if [ -f "${CLIENT_DIR}/${CLIENT_NAME}.conf" ]; then
    echo -e "${RED}Клиент ${CLIENT_NAME} уже существует${NC}"
    exit 1
fi

# Генерация ключей
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Определение следующего IP
LAST_IP=$(grep "Address = 10.0.0." ${CLIENT_DIR}/*.conf 2>/dev/null | sort -V | tail -1 | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4)
if [ -z "$LAST_IP" ]; then
    CLIENT_IP="10.0.0.2"
else
    CLIENT_IP="10.0.0.$((LAST_IP + 1))"
fi

SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
SERVER_IP=$(curl -s ifconfig.me)

# Добавление в серверную конфигурацию
cat >> /etc/wireguard/wg0.conf << EOF

# Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# Создание клиентской конфигурации
mkdir -p $CLIENT_DIR
cat > ${CLIENT_DIR}/${CLIENT_NAME}.conf << EOF
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

# Перезапуск WireGuard
wg syncconf wg0 <(wg-quick strip wg0)

# Генерация QR-кода
qrencode -t ansiutf8 < ${CLIENT_DIR}/${CLIENT_NAME}.conf > ${CLIENT_DIR}/${CLIENT_NAME}-qr.txt

echo -e "${GREEN}✓ Клиент ${CLIENT_NAME} добавлен${NC}"
echo -e "${YELLOW}Конфигурация: ${CLIENT_DIR}/${CLIENT_NAME}.conf${NC}"
echo -e "${YELLOW}QR-код: ${CLIENT_DIR}/${CLIENT_NAME}-qr.txt${NC}"
EOFWGADD

chmod +x /usr/local/bin/wg-add-client

echo -e "${YELLOW}[12/12] Генерация финального отчета...${NC}"

SERVER_IP=$(curl -s ifconfig.me)

cat > /root/vpn-credentials.txt << EOF
╔═══════════════════════════════════════════════════════════╗
║          VPN СЕРВЕР - ПОЛНАЯ КОНФИГУРАЦИЯ                 ║
╚═══════════════════════════════════════════════════════════╝

Сервер: ${SERVER_IP}
Установлено: $(date)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. WIREGUARD (Максимальная скорость)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Порт: 51820 (UDP)
Клиентов: ${WG_CLIENTS}
Конфигурации: /root/wireguard-clients/

Команды:
  wg show                    # показать подключения
  wg-add-client              # добавить клиента
  systemctl restart wg-quick@wg0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. XRAY VLESS (Защита от блокировок)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Порт: 443 (TCP)
UUID: ${XRAY_UUID}
Public Key: ${XRAY_PUBLIC_KEY}

Строка подключения:
vless://${XRAY_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&type=tcp&fp=chrome#MyVPN-XRay

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. SHADOWSOCKS (Резервный канал)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Сервер: ${SERVER_IP}
Порт: 8388
Пароль: ${SS_PASSWORD}
Метод: chacha20-ietf-poly1305
Obfs: tls

ss://${SS_PASSWORD}@${SERVER_IP}:8388

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ПОЛЕЗНЫЕ КОМАНДЫ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  vpn-status                 # статус всех сервисов
  wg-add-client              # добавить WireGuard клиента
  journalctl -u xray -f      # логи XRay
  journalctl -u wg-quick@wg0 # логи WireGuard
  htop                       # мониторинг системы
  nethogs                    # сетевой трафик
  ufw status numbered        # правила firewall

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
РЕКОМЕНДАЦИИ ПО ИСПОЛЬЗОВАНИЮ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Используйте WireGuard для максимальной скорости
• XRay — при блокировках WireGuard
• Shadowsocks — как резервный вариант

Регулярно обновляйте систему:
  apt update && apt upgrade -y

╚═══════════════════════════════════════════════════════════╝
EOF

cat /root/vpn-credentials.txt

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Вся информация сохранена в:${NC}"
echo -e "  /root/vpn-credentials.txt"
echo ""
echo -e "${YELLOW}Для проверки статуса:${NC}"
echo -e "  vpn-status"
echo ""
