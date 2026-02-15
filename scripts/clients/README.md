# Client Onboarding Helpers

These helpers generate a small "client pack" text file you can send to a user.

They intentionally avoid trying to be "auto installers" (mobile platforms do not allow that).
The safest and simplest flow is always:

1. Copy `vless://...` or subscription URL from x-ui
2. Paste/import it into the client app
3. Enable VPN/TUN (device-wide) mode

## Scripts

- `scripts/clients/onboard-ios.ps1`
- `scripts/clients/onboard-android.ps1`
- `scripts/clients/onboard-windows.ps1`
- `scripts/clients/onboard-macos.ps1`
- `scripts/clients/onboard-ios.sh`
- `scripts/clients/onboard-android.sh`
- `scripts/clients/onboard-windows.sh`
- `scripts/clients/onboard-macos.sh`

## Usage (Windows PowerShell)

```powershell
# iOS pack (Hiddify / Karing / sing-box VT)
.\scripts\clients\onboard-ios.ps1 -VlessLink "<paste vless://...>" -OutFile ".\\client-pack-ios.txt"

# or using a subscription URL (preferred if you rotate clients often)
.\scripts\clients\onboard-ios.ps1 -SubscriptionUrl "<paste subscription url>" -OutFile ".\\client-pack-ios.txt"
```

## Usage (Linux/macOS bash)

```bash
chmod +x ./scripts/clients/onboard-ios.sh
./scripts/clients/onboard-ios.sh --vless-link "<paste vless://...>" --out ./client-pack-ios.txt

# or using a subscription URL
./scripts/clients/onboard-ios.sh --subscription-url "<paste subscription url>" --out ./client-pack-ios.txt
```
