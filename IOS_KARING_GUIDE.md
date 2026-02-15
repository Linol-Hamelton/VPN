# iOS (Karing) Guide for x-ui / XRay (VLESS Reality)

Karing is a free iOS client that can import `vless://...` links and subscription URLs.

## 1) Install Karing

Install Karing from the App Store (search for "Karing").

## 2) Export a Working Link From x-ui

In x-ui:
1. Open **Inbounds**.
2. Select your inbound (**VLESS + Reality**).
3. Click **Share / Export**.
4. Copy either:
   - a **`vless://...`** link (single profile), or
   - a **subscription URL** (preferred if you want to manage multiple clients).

Do not retype SNI/ShortID/publicKey manually.

## 3) Import Into Karing

In Karing:
1. Add configuration:
   - If you have a `vless://...` link: import from clipboard / paste the link.
   - If you have a subscription URL: add subscription and refresh.
2. Select the imported node/profile.
3. Enable VPN mode (device-wide / TUN) and connect.
4. Approve iOS VPN profile installation when prompted.

## Common Problems

### Timeout / Connection Refused
Usually means the inbound TCP port is not reachable from the internet, or XRay is not listening.

Server checks:
```bash
sudo ss -tlnp | egrep ':(443|<PORT>)\\b'
sudo ufw status | egrep '(443|<PORT>)/tcp'
sudo journalctl -u x-ui -n 50 --no-pager
```

### Connected But Slow
Most common safe optimizations are on the server side:
- Disable access logs and verbose logging.
- Disable traffic statistics if you don't need them.
- Prefer VLESS Reality with flow `xtls-rprx-vision` (client must support it).

