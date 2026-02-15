# Free iOS Alternatives to Shadowrocket (for VLESS Reality / x-ui)

If you need a free iPhone client for your x-ui / XRay setup (for example, VLESS + Reality), these options are the most practical.

## Option 1 (Recommended): Hiddify (Free, Open Source)

Hiddify is a free, open-source client (Sing-box based) and is widely used with VLESS + Reality.

How to connect:
1. In x-ui: Inbounds -> your inbound -> Share/Export -> copy the `vless://...` link.
2. On iPhone: open Hiddify -> add/import from clipboard (or paste the link).
3. Select the profile and tap Connect.

Notes:
- Prefer VLESS TCP + Reality for best compatibility.
- If you use a custom port, make sure it is reachable from the internet (firewall + provider).

## Option 2: Karing (Free)

Karing is a free iOS client that focuses on subscriptions and modern proxy cores.

How to connect:
1. Import the `vless://...` link (or your subscription URL) into Karing.
2. Select the profile and connect.

See also: `IOS_KARING_GUIDE.md`.

## Option 3: Sing-box (VT) (Free)

Sing-box (VT) is a free Sing-box based client. It can be a good fallback if you want something close to upstream Sing-box.

## If You Want a "2 Buttons" App (Paste Link + Run)

You cannot "wrap" Shadowrocket UI. To build your own iOS app you must implement a VPN tunnel using Apple NetworkExtension and embed a proxy core (typically Sing-box).

Practical approach:
- Fork an existing open-source client (Hiddify or Karing) and simplify the UI to: "Paste link" + "Connect".
- Expect: Apple Developer account, iOS VPN entitlements, App Store review constraints, and ongoing maintenance.
