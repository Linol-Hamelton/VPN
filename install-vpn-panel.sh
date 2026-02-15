#!/bin/bash

set -euo pipefail

# You can override these via environment variables:
#   PANEL_PORT=6098 PANEL_LANG=en-US sudo bash install-vpn-panel.sh
PANEL_PORT="${PANEL_PORT:-6098}"
PANEL_LANG="${PANEL_LANG:-en-US}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Установка VPN сервера с 3X-UI панелью${NC}"
echo -e "${GREEN}================================================${NC}"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}" 
   exit 1
fi

# Обновление системы
echo -e "${YELLOW}[1/8] Обновление системы...${NC}"
DEBIAN_FRONTEND=noninteractive apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Установка необходимых пакетов
echo -e "${YELLOW}[2/8] Установка базовых пакетов...${NC}"
DEBIAN_FRONTEND=noninteractive apt install -y curl wget nano ufw fail2ban unattended-upgrades htop openssl sqlite3 locales

# Настройка автоматических обновлений безопасности
echo -e "${YELLOW}[3/8] Настройка автоматических обновлений...${NC}"
dpkg-reconfigure -plow unattended-upgrades

# Настройка firewall
echo -e "${YELLOW}[4/8] Настройка firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 443/tcp comment 'HTTPS/XRay'
ufw allow 80/tcp comment 'HTTP'
ufw allow "${PANEL_PORT}/tcp" comment '3X-UI Panel'
ufw --force enable

# Оптимизация сетевых параметров ядра
echo -e "${YELLOW}[5/8] Оптимизация сетевых параметров...${NC}"
cat >> /etc/sysctl.conf << EOF

# VPN Performance Optimization
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1

# TCP BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Connection tuning
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF

sysctl -p

# Настройка Fail2Ban
echo -e "${YELLOW}[6/8] Настройка защиты от брутфорса...${NC}"
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Генерация учетных данных ДО установки
PANEL_USER="admin_$(openssl rand -hex 4)"
PANEL_PASS="$(openssl rand -base64 16)"
# PANEL_PORT is set at the top (default 6098) and can be overridden via env.

# Установка 3X-UI с использованием переменных окружения
echo -e "${YELLOW}[7/8] Установка 3X-UI панели управления...${NC}"
export INSTALL_MODE=auto
export PANEL_USERNAME="${PANEL_USER}"
export PANEL_PASSWORD="${PANEL_PASS}"
export PANEL_PORT="${PANEL_PORT}"

bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

# Force English locale on the server (this does not translate x-ui CLI menu).
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
locale-gen en_US.UTF-8 || true
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true

# Apply panel port + UI language via sqlite (works across most x-ui/3x-ui forks).
XUI_DB="/etc/x-ui/x-ui.db"
if [[ -f "$XUI_DB" ]]; then
  SETTINGS_TABLE="$(sqlite3 "$XUI_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('setting','settings') ORDER BY (name='settings') DESC LIMIT 1;")"
  if [[ -n "$SETTINGS_TABLE" ]]; then
    COLS="$(sqlite3 -separator '|' "$XUI_DB" "PRAGMA table_info(${SETTINGS_TABLE});")"
    KEY_COL="$(echo "$COLS" | awk -F'|' 'tolower($2)=="key" || tolower($2)=="name" {print $2; exit}')"
    VAL_COL="$(echo "$COLS" | awk -F'|' 'tolower($2)=="value" || tolower($2)=="val" {print $2; exit}')"
    if [[ -n "$KEY_COL" && -n "$VAL_COL" ]]; then
      sqlite3 "$XUI_DB" "UPDATE ${SETTINGS_TABLE} SET ${VAL_COL}='${PANEL_PORT}' WHERE ${KEY_COL} IN ('web.port','webPort','panel.port','panelPort','port');" || true
      sqlite3 "$XUI_DB" "UPDATE ${SETTINGS_TABLE} SET ${VAL_COL}='${PANEL_LANG}' WHERE ${KEY_COL} IN ('web.lang','web.language','web.locale','language','lang','locale');" || true
    fi
  fi
  systemctl restart x-ui || true
fi

echo -e "${YELLOW}[8/8] Финальная настройка...${NC}"

# Получение IP адреса сервера
SERVER_IP=$(curl -s ifconfig.me)

# Вывод итоговой информации
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  ✓ Установка завершена успешно!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Доступ к панели управления:${NC}"
echo -e "URL: ${GREEN}http://${SERVER_IP}:${PANEL_PORT}${NC}"
echo -e "Пользователь: ${GREEN}${PANEL_USER}${NC}"
echo -e "Пароль: ${GREEN}${PANEL_PASS}${NC}"
echo ""
echo -e "${YELLOW}ВАЖНО: Сохраните эти данные!${NC}"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "1. Войдите в панель управления"
echo "2. Создайте VLESS-Reality конфигурацию на порту 443"
echo "3. Скачайте конфигурацию клиента и подключитесь"
echo ""
echo -e "${YELLOW}Для изменения пароля панели:${NC}"
echo "x-ui"
echo ""
echo -e "${GREEN}================================================${NC}"

# Сохранение учетных данных в файл
cat > /root/vpn-credentials.txt << EOF
3X-UI Panel Access:
===================
URL: http://${SERVER_IP}:${PANEL_PORT}
Username: ${PANEL_USER}
Password: ${PANEL_PASS}

Installation Date: $(date)
Server IP: ${SERVER_IP}
EOF

echo -e "${GREEN}Учетные данные сохранены в /root/vpn-credentials.txt${NC}"
