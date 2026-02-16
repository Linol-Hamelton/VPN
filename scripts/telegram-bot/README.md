# Telegram Onboarding Bot (iOS first)

This bot implements:

- `/start` -> buttons (Android / iOS / Windows / MacOS)
- Anyone can request access by choosing a platform.
- Admin must approve via inline buttons (Approve/Reject).
- For now only iOS provisioning is implemented:
  - Telegram user id is used as x-ui client `email`
  - bot calls `scripts/x-ui/create-ios-user.sh`
  - sends back `vless://...` and a Karing deep-link (`karing://install-config?...`)

## Requirements (server)

- Python 3
- Ubuntu/Debian: `python3-venv` (otherwise `python -m venv` fails with "ensurepip is not available")
- x-ui installed and running
- This repo available on the server (example: `/root/VPN`)
- Bot must run as root (it uses `systemctl stop/start x-ui` via `create-ios-user.sh`)

## Setup

1. Create a separate Telegram bot and get token (do not reuse x-ui's internal bot token).
2. Export a working `vless://...` link from x-ui (Share) and save it:

```bash
sudo mkdir -p /etc/x-ui
sudo nano /etc/x-ui/template.vless
```

The file must contain a real exported link for your REALITY inbound, including `pbk`, `sni`, `sid` in query params
(example pattern: `...&pbk=...&sni=...&sid=...`).

3. Install deps:

```bash
sudo apt update
sudo apt install -y python3-venv

python3 -m venv /opt/vpn-onboard-bot/.venv
/opt/vpn-onboard-bot/.venv/bin/pip install -r /root/VPN/scripts/telegram-bot/requirements.txt
```

4. Create env file (example `/etc/vpn-onboard-bot.env`):

```bash
BOT_TOKEN=123456:ABCDEF
BOT_ADMIN_IDS=123456789
XUI_SERVER_HOST=144.31.227.53
XUI_INBOUND_PORT=32062
XUI_DB=/etc/x-ui/x-ui.db
XUI_TEMPLATE_VLESS_FILE=/etc/x-ui/template.vless
BOT_OUTPUT_DIR=/var/lib/vpn-onboard
BOT_LOCK_FILE=/var/lock/vpn-onboard-xui.lock
BOT_PENDING_FILE=/var/lib/vpn-onboard/pending.json

# Optional: send client pack .txt as a Telegram file (default: 0)
BOT_SEND_CLIENT_PACK=0

# Optional (recommended for iOS "auto import" reliability):
# A subscription/config URL template that Karing can fetch over http/https.
# Supported placeholders: {email}, {uuid}, {client_id}, {server}, {port}
# Example:
# XUI_SUB_URL_TEMPLATE=http://{server}:2096/sub/{email}
# XUI_SUB_URL_TEMPLATE=https://sub.example.com/sub/{email}
XUI_SUB_URL_TEMPLATE=
```

5. Run (from repo root):

```bash
cd /root/VPN
/opt/vpn-onboard-bot/.venv/bin/python scripts/telegram-bot/onboard_bot.py --env-file /etc/vpn-onboard-bot.env
```

If polling fails, ensure there is no webhook set on this token:

```bash
curl -s "https://api.telegram.org/bot$BOT_TOKEN/deleteWebhook" | jq
```
