#!/usr/bin/env bash
set -euo pipefail

vless_link=""
sub_url=""
out_file="./client-pack-ios.txt"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clients/onboard-ios-new.sh [--vless-link "vless://..."] [--subscription-url "https://..."] [--out "./client-pack-ios.txt"]

Notes:
  - This script generates a simplified setup guide for the 3-button VPN app.
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
  echo "iOS setup for Simplified VPN App (3-button interface)"
  echo
  echo "Your VPN profile is ready!"
  echo
  echo "1) Download the simplified VPN app:"
  echo "   Download link: https://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa"
  echo
  echo "2) After installation, open the app and tap 'Add Profile'"
  echo
  echo "3) You can add the profile in one of these ways:"
  echo "   - Tap the 'Add Profile' button and paste this link:"
  echo "     [VLESS_LINK_PLACEHOLDER]"
  echo "   - Or scan the QR code from your computer (link above)"
  echo
  echo "4) After adding the profile tap 'Start VPN' to connect"
  echo
  echo "5) Tap 'Settings' to change parameters or disconnect"
  echo
  echo "The app has a simple interface with just three buttons for maximum convenience:"
  echo "   - Add Profile: Add new VPN profiles"
  echo "   - Start VPN: Connect to the VPN"
  echo "   - Settings: Change settings, view speed indicators, or disconnect"
  echo
  echo "Speed indicators (download/upload speeds and ping) are displayed in real-time."
  echo "In Settings, you can configure which apps route through VPN vs direct connection."
} > "$out_file"

echo "Wrote: $out_file"set -euo pipefail

vless_link=""
sub_url=""
out_file="./client-pack-ios.txt"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clients/onboard-ios-new.sh [--vless-link "vless://..."] [--subscription-url "https://..."] [--out "./client-pack-ios.txt"]

Notes:
  - This script generates a simplified setup guide for the 3-button VPN app.
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
  echo "iOS setup for Simplified VPN App (3-button interface)"
  echo
  echo "Your VPN profile is ready!"
  echo
  echo "1) Download the simplified VPN app:"
  echo "   Download link: https://vm779762.hosted-by.u1host.com/downloads/hiddify-ios.ipa"
  echo
  echo "2) After installation, open the app and tap 'Add Profile'"
  echo
  echo "3) You can add the profile in one of these ways:"
  echo "   - Tap the 'Add Profile' button and paste this link:"
  echo "     [VLESS_LINK_PLACEHOLDER]"
  echo "   - Or scan the QR code from your computer (link above)"
  echo
  echo "4) After adding the profile tap 'Start VPN' to connect"
  echo
  echo "5) Tap 'Settings' to change parameters or disconnect"
  echo
  echo "The app has a simple interface with just three buttons for maximum convenience:"
  echo "   - Add Profile: Add new VPN profiles"
  echo "   - Start VPN: Connect to the VPN"
  echo "   - Settings: Change settings, view speed indicators, or disconnect"
  echo
  echo "Speed indicators (download/upload speeds and ping) are displayed in real-time."
  echo "In Settings, you can configure which apps route through VPN vs direct connection."
} > "$out_file"

echo "Wrote: $out_file"
