#!/usr/bin/env bash
set -euo pipefail

email=""
inbound_port=""
db="/etc/x-ui/x-ui.db"

usage() {
  cat <<'EOF'
Delete an x-ui VLESS client (by email) from an inbound and remove its traffic row.

Usage:
  sudo bash ./scripts/x-ui/delete-ios-user.sh --email "ios1" --inbound-port 32062

Notes:
  - Stops x-ui, edits DB, starts x-ui back.
  - If you need to delete multiple users, run the command multiple times.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) email="${2:-}"; shift 2 ;;
    --inbound-port) inbound_port="${2:-}"; shift 2 ;;
    --db) db="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$email" || -z "$inbound_port" ]]; then
  usage
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)." >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

stopped=0
if systemctl is-active --quiet x-ui; then
  systemctl stop x-ui
  stopped=1
fi

cleanup() {
  if [[ "$stopped" == "1" ]]; then
    systemctl start x-ui >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

backup="/root/x-ui.db.bak.$(date +%F-%H%M%S)"
cp -a "$db" "$backup"

python3 "$repo_root/scripts/x-ui/remove-vless-client.py" \
  --db "$db" \
  --inbound-port "$inbound_port" \
  --email "$email" \
  --json

systemctl start x-ui
stopped=0

echo "Backup: $backup"

