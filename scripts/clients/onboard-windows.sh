#!/usr/bin/env bash
set -euo pipefail

vless_link=""
sub_url=""
out_file="./client-pack-windows.txt"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clients/onboard-windows.sh [--vless-link "vless://..."] [--subscription-url "https://..."] [--out "./client-pack-windows.txt"]
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
  echo "Windows setup (x-ui / XRay, VLESS Reality)"
  echo
  echo "1) Install a client app:"
  echo "- v2rayN (Windows)"
  echo
  echo "2) Import config:"
  if [[ -n "$sub_url" ]]; then
    echo "- Preferred: add subscription URL in v2rayN:"
    echo "  $sub_url"
  fi
  if [[ -n "$vless_link" ]]; then
    echo "- Or import a single VLESS link:"
    echo "  $vless_link"
  fi
  if [[ -z "$sub_url" && -z "$vless_link" ]]; then
    echo "- Copy the vless:// link (or subscription URL) from x-ui and import it into v2rayN."
  fi
  echo
  echo "3) Connect:"
  echo "- Select the imported profile (Configuration) and connect."
  echo "- If you want device-wide tunneling, enable TUN mode (if you use it)."
  echo
  echo "Notes:"
  echo "- If it times out: the inbound TCP port is blocked or not listening on the server."
} > "$out_file"

echo "Wrote: $out_file"

