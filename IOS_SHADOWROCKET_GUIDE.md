# iOS (Shadowrocket) Guide for x-ui / XRay (VLESS Reality)

This guide assumes you already created a working inbound in **x-ui** (typically **VLESS + Reality**) and you have a `vless://...` share link or QR code.

## 1) Get a VLESS Reality Link From x-ui

1. Open x-ui panel.
2. Go to **Inbounds**.
3. Select your inbound (VLESS + Reality).
4. Click **Share / Export** and copy the **`vless://...`** link (or show QR).

Keep these values consistent (they are embedded in the link):
- Server: `IP or domain`
- Port: `443` (recommended) or your custom TCP port
- UUID
- Reality: `publicKey (pbk)`, `shortId (sid)`, `sni`, `fingerprint (fp)`

## 2) Import Into Shadowrocket

1. Install **Shadowrocket** from the App Store.
2. Open Shadowrocket.
3. Import the config:
   - If you have a link: use **Add by URL** (or paste from clipboard if Shadowrocket suggests it).
   - If you have a QR: use **Scan QR Code** and scan it from your screen.
4. Select the imported server/profile (make sure it is checked/selected).
5. Toggle the main switch to **ON** and allow iOS to add the VPN profile.

## 3) Make It “Works Everywhere”

In Shadowrocket:
- Prefer **VPN/TUN** mode (device-wide) if you want all apps to use the tunnel.
- If you use a non-443 port, confirm your server firewall allows it (`ufw allow <PORT>/tcp`) and the hosting provider does not block it.

## Common Problems

### Timeout / No Connection
Usually means the server port is not reachable from the internet.

Server-side checks:
```bash
sudo ss -tlnp | grep :<PORT>
sudo ufw status | grep <PORT>
```

If the port is reachable but still times out:
- Use port **443/tcp** for VLESS Reality if possible.
- Avoid uncommon high ports if your provider/ISP filters them.

### “Connected” But Some Apps Don’t Work
Enable device-wide VPN/TUN mode in Shadowrocket (not just a system proxy mode), and verify DNS is going through the tunnel.

