#!/usr/bin/env bash
set -euo pipefail

vless_link=""
sub_url=""
out_file="./client-pack-ios.txt"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clients/onboard-ios.sh [--vless-link "vless://..."] [--subscription-url "https://..."] [--out "./client-pack-ios.txt"]

Notes:
  - This script generates a small text file you can send to a user.
  - Prefer using the exported vless:// link or subscription URL from x-ui (do not enter fields manually).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vless-link)
      vless_link="${2:-}"; shift 2 ;;
    --subscription-url)
      sub_url="${2:-}"; shift 2 ;;
    --out)
      out_file="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

mkdir -p "$(dirname "$out_file")" 2>/dev/null || true

{
  echo "iOS setup (x-ui / XRay, VLESS Reality)"
  echo
  echo "1) Install a free client app (pick one):"
  echo "- Karing (App Store): https://apps.apple.com/app/karing/id6472431552"
  echo "- sing-box VT (App Store): https://apps.apple.com/app/sing-box-vt/id6673731168"
  echo
  echo "2) Import config:"
  if [[ -n "$sub_url" ]]; then
    echo "- Preferred: add subscription URL in the app:"
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
  echo "3) Enable device-wide tunnel:"
  echo "- Turn ON VPN/TUN (device-wide) mode in the app"
  echo "- Approve iOS VPN profile installation when prompted"
  echo
  echo "Notes:"
  echo "- For VLESS Reality, do not enter fields manually. Always use the exported link from x-ui."
  echo "- If it times out: the inbound TCP port is blocked or not listening on the server."
} > "$out_file"

echo "Wrote: $out_file"
