#!/bin/bash
set -euo pipefail

# Fixes common x-ui/3x-ui issues:
# - panel port stuck on an unexpected value
# - web UI language set to an incomplete locale (ru-RU errors)
# - server locale not English
#
# Usage:
#   sudo ./x-ui-fix.sh --port 6098 --lang en-US
#
# Notes:
# - This script uses sqlite3 to update /etc/x-ui/x-ui.db settings.
# - Key names can differ across x-ui forks/versions; the script updates common ones
#   and prints the discovered settings table for verification.

PORT="6098"
LANG_CODE="en-US"
APPLY_LOCALE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="${2:?missing value for --port}"
      shift 2
      ;;
    --lang|--language)
      LANG_CODE="${2:?missing value for --lang}"
      shift 2
      ;;
    --no-locale)
      APPLY_LOCALE=0
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: sudo ./x-ui-fix.sh [--port 6098] [--lang en-US] [--no-locale]

Updates x-ui panel port and UI language in /etc/x-ui/x-ui.db and restarts the service.
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3
fi

if [[ "$APPLY_LOCALE" -eq 1 ]]; then
  if ! command -v locale-gen >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y locales
  fi
  sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
  locale-gen en_US.UTF-8 || true
  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true
fi

DB="/etc/x-ui/x-ui.db"
if [[ ! -f "$DB" ]]; then
  echo "x-ui db not found at $DB" >&2
  echo "If your fork uses a different path, locate it (e.g. find /etc -name 'x-ui.db')." >&2
  exit 1
fi

echo "DB: $DB"
echo "Target port: $PORT"
echo "Target UI language: $LANG_CODE"

CURRENT_LISTEN_PORT="$(ss -tlnp 2>/dev/null | awk '/x-ui/ {print $4}' | awk -F: '{print $NF}' | head -n 1 || true)"
if [[ -n "$CURRENT_LISTEN_PORT" ]]; then
  echo "Detected current listen port (from ss): $CURRENT_LISTEN_PORT"
fi

SETTINGS_TABLE="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('setting','settings') ORDER BY (name='settings') DESC LIMIT 1;")"
if [[ -z "$SETTINGS_TABLE" ]]; then
  echo "Could not find settings table in $DB (expected 'setting' or 'settings')." >&2
  echo "Tables:" >&2
  sqlite3 "$DB" ".tables" >&2 || true
  exit 1
fi

COLS="$(sqlite3 -separator '|' "$DB" "PRAGMA table_info(${SETTINGS_TABLE});")"
KEY_COL="$(echo "$COLS" | awk -F'|' 'tolower($2)=="key" || tolower($2)=="name" {print $2; exit}')"
VAL_COL="$(echo "$COLS" | awk -F'|' 'tolower($2)=="value" || tolower($2)=="val" {print $2; exit}')"
if [[ -z "$KEY_COL" || -z "$VAL_COL" ]]; then
  echo "Could not identify key/value columns in ${SETTINGS_TABLE}." >&2
  echo "PRAGMA table_info(${SETTINGS_TABLE}):" >&2
  echo "$COLS" >&2
  exit 1
fi

echo ""
echo "Settings table: ${SETTINGS_TABLE} (${KEY_COL}, ${VAL_COL})"

# Show current web-related settings for debugging.
echo ""
echo "Current settings (filtered):"
sqlite3 "$DB" "SELECT ${KEY_COL},${VAL_COL} FROM ${SETTINGS_TABLE} WHERE ${KEY_COL} LIKE 'web.%' OR ${KEY_COL} LIKE '%lang%' OR ${KEY_COL} LIKE '%locale%' OR ${KEY_COL} LIKE '%base%path%' ORDER BY ${KEY_COL};" || true

# If we know the current listen port, also update any matching settings that look like ports.
if [[ -n "${CURRENT_LISTEN_PORT}" ]]; then
  echo ""
  echo "Settings with value == current port (filtered by key contains 'port'):"
  sqlite3 "$DB" "SELECT ${KEY_COL},${VAL_COL} FROM ${SETTINGS_TABLE} WHERE ${VAL_COL}='${CURRENT_LISTEN_PORT}' AND lower(${KEY_COL}) LIKE '%port%' ORDER BY ${KEY_COL};" || true

  # This tends to catch forks that store the panel port under non-standard keys.
  sqlite3 "$DB" "UPDATE ${SETTINGS_TABLE} SET ${VAL_COL}='${PORT}' WHERE ${VAL_COL}='${CURRENT_LISTEN_PORT}' AND lower(${KEY_COL}) LIKE '%port%';" || true
fi

# Update common keys. If a key doesn't exist, UPDATE is a no-op.
sqlite3 "$DB" "UPDATE ${SETTINGS_TABLE} SET ${VAL_COL}='${PORT}' WHERE ${KEY_COL} IN ('web.port','webPort','panel.port','panelPort','port');"
sqlite3 "$DB" "UPDATE ${SETTINGS_TABLE} SET ${VAL_COL}='${LANG_CODE}' WHERE ${KEY_COL} IN ('web.lang','web.language','web.locale','language','lang','locale');"

echo ""
echo "Settings after update (filtered):"
sqlite3 "$DB" "SELECT ${KEY_COL},${VAL_COL} FROM ${SETTINGS_TABLE} WHERE ${KEY_COL} LIKE 'web.%' OR ${KEY_COL} LIKE '%lang%' OR ${KEY_COL} LIKE '%locale%' OR ${KEY_COL} LIKE '%base%path%' ORDER BY ${KEY_COL};" || true

echo ""
echo "All settings that look like ports (for debugging):"
PORT_KEYS="$(sqlite3 "$DB" "SELECT ${KEY_COL},${VAL_COL} FROM ${SETTINGS_TABLE} WHERE lower(${KEY_COL}) LIKE '%port%' ORDER BY ${KEY_COL};" || true)"
echo "${PORT_KEYS}"

SERVICE=""
if systemctl list-unit-files | awk '{print $1}' | grep -qx "x-ui.service"; then
  SERVICE="x-ui"
elif systemctl list-unit-files | awk '{print $1}' | grep -qx "3x-ui.service"; then
  SERVICE="3x-ui"
fi

if [[ -n "$SERVICE" ]]; then
  systemctl restart "$SERVICE"
  systemctl --no-pager --full status "$SERVICE" || true
else
  echo "Could not detect x-ui service unit name. Try: systemctl restart x-ui" >&2
fi

# If DB has no port-related keys (common on some forks), try the official CLI setter.
if [[ -z "${PORT_KEYS//[[:space:]]/}" ]]; then
  if [[ -x /usr/local/x-ui/x-ui ]]; then
    echo ""
    echo "No '*port*' keys found in DB; trying: /usr/local/x-ui/x-ui setting -port ${PORT}"
    /usr/local/x-ui/x-ui setting -port "${PORT}" || true
    if [[ -n "$SERVICE" ]]; then
      systemctl restart "$SERVICE"
    fi
  fi
fi

echo ""
echo "Listening sockets (x-ui):"
ss -tlnp 2>/dev/null | grep -E "(x-ui|:${PORT})" || true

echo ""
echo "Try locally on the server:"
echo "  curl -v http://localhost:${PORT}/ 2>&1 | head -n 20"
echo "If x-ui is configured for HTTPS, use:"
echo "  curl -vk https://localhost:${PORT}/ 2>&1 | head -n 20"
