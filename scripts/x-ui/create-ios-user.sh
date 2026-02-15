#!/usr/bin/env bash
set -euo pipefail

email=""
server_host=""
inbound_port=""
flow="xtls-rprx-vision"
out_file="./client-pack-ios.txt"
db="/etc/x-ui/x-ui.db"
pbk=""

usage() {
  cat <<'EOF'
Create an x-ui VLESS client (for iOS) and generate a ready-to-send client pack.

Usage:
  sudo bash ./scripts/x-ui/create-ios-user.sh --email "user1" --server "YOUR_DOMAIN_OR_IP" --inbound-port 32062 [--out ./client-pack-ios-user1.txt]

Notes:
  - This script edits x-ui SQLite DB and restarts x-ui (xray) to apply changes.
  - It will try to build a vless:// link automatically. If pbk derivation fails,
    you'll still get the created UUID and a hint to export the link from x-ui UI.
  - You can pass --pbk "<publicKey>" to avoid pbk derivation (pbk is not secret).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) email="${2:-}"; shift 2 ;;
    --server) server_host="${2:-}"; shift 2 ;;
    --inbound-port) inbound_port="${2:-}"; shift 2 ;;
    --flow) flow="${2:-}"; shift 2 ;;
    --pbk) pbk="${2:-}"; shift 2 ;;
    --db) db="${2:-}"; shift 2 ;;
    --out) out_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$email" || -z "$server_host" || -z "$inbound_port" ]]; then
  usage
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)." >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

mkdir -p "$(dirname "$out_file")" 2>/dev/null || true

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

pbk_args=()
if [[ -n "$pbk" ]]; then
  pbk_args=(--pbk "$pbk")
fi

json_out="$(python3 "$repo_root/scripts/x-ui/add-vless-client.py" \
  --db "$db" \
  --inbound-port "$inbound_port" \
  --email "$email" \
  --flow "$flow" \
  --server "$server_host" \
  "${pbk_args[@]}" \
  --json \
)"

echo "$json_out" > "${out_file}.json"

systemctl start x-ui
stopped=0

vless_link="$(printf '%s' "$json_out" | python3 -c "import sys,json; o=json.load(sys.stdin); print(o.get('vless_link',''))" 2>/dev/null || true)"
client_id="$(printf '%s' "$json_out" | python3 -c "import sys,json; o=json.load(sys.stdin); print(o.get('id',''))" 2>/dev/null || true)"
link_error="$(printf '%s' "$json_out" | python3 -c "import sys,json; o=json.load(sys.stdin); print(o.get('link_error',''))" 2>/dev/null || true)"

if [[ -n "$vless_link" ]]; then
  bash "$repo_root/scripts/clients/onboard-ios.sh" --vless-link "$vless_link" --out "$out_file" >/dev/null
  echo "OK: created client '$email' (id: $client_id)"
  echo "Wrote: $out_file"
else
  {
    echo "iOS setup (x-ui / XRay, VLESS Reality)"
    echo
    echo "Client created:"
    echo "- email: $email"
    echo "- id: $client_id"
    echo
    echo "Link was NOT generated automatically:"
    echo "- $link_error"
    echo
    echo "Next:"
    echo "- Open x-ui -> Inbounds -> your inbound ($inbound_port) -> Share/Export -> copy the vless:// link"
  } > "$out_file"
  echo "OK: created client '$email' (id: $client_id)"
  echo "Wrote: $out_file (without vless link)"
fi

echo "Backup: $backup"
echo "JSON: ${out_file}.json"
