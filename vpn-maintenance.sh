#!/bin/bash

# Скрипт автоматического обслуживания VPN

# Проверка доступности сервисов
check_services() {
    SERVICES=("wg-quick@wg0" "xray" "shadowsocks-libev")
    
    for service in "${SERVICES[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo "$(date): $service is down, restarting..." >> /var/log/vpn-maintenance.log
            systemctl restart $service
        fi
    done
}

# Очистка логов старше 7 дней
cleanup_logs() {
    find /var/log/xray -name "*.log" -mtime +7 -delete
    journalctl --vacuum-time=7d
}

# Проверка использования диска
check_disk() {
    USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $USAGE -gt 90 ]; then
        echo "$(date): Disk usage is ${USAGE}%" >> /var/log/vpn-maintenance.log
    fi
}

# Обновление GeoIP баз
update_geoip() {
    if [ -d "/usr/local/share/xray" ]; then
        wget -q -O /tmp/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
        wget -q -O /tmp/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
        mv /tmp/geoip.dat /usr/local/share/xray/
        mv /tmp/geosite.dat /usr/local/share/xray/
        systemctl restart xray
    fi
}

# Выполнение проверок
check_services
cleanup_logs
check_disk
update_geoip

echo "$(date): Maintenance completed" >> /var/log/vpn-maintenance.log
