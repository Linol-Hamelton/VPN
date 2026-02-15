#!/usr/bin/env bash
set -euo pipefail

vless_link=""
sub_url=""
out_file="./client-pack-android.txt"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clients/onboard-android.sh [--vless-link "vless://..."] [--subscription-url "https://..."] [--out "./client-pack-android.txt"]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vless-link) vless_link="${2:-}"; shift 2 ;;
    --subscription-url) sub_url="${2:-}"; shift 2 ;;
    --out) out_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$out_file")" 2>/dev/null || true

{
  echo "Android setup (x-ui / XRay, VLESS Reality)"
  echo
  echo "1) Install a client app (pick one):"
  echo "- v2rayNG"
  echo "- sing-box based clients"
  echo
  echo "2) Import config:"
  if [[ -n "$sub_url" ]]; then
    echo "- Preferred: add subscription URL:"
    echo "  $sub_url"
  fi
  if [[ -n "$vless_link" ]]; then
    echo "- Or import a single VLESS link:"
    echo "  $vless_link"
  fi
  if [[ -z "$sub_url" && -z "$vless_link" ]]; then
    echo "- Copy the vless:// link (or subscription URL) from x-ui and paste it into the app."
  fi
  echo
  echo "3) Enable VPN mode and connect."
  echo
  echo "Notes:"
  echo "- If it times out: the inbound TCP port is blocked or not listening on the server."
} > "$out_file"

echo "Wrote: $out_file"

