param(
  [Parameter(Mandatory=$false)]
  [string]$VlessLink,

  [Parameter(Mandatory=$false)]
  [string]$SubscriptionUrl,

  [Parameter(Mandatory=$false)]
  [string]$OutFile = ".\\client-pack-ios.txt"
)

function Fail($msg) {
  Write-Error $msg
  exit 1
}

if (-not $VlessLink -and -not $SubscriptionUrl) {
  Write-Host "Tip: paste a vless:// link OR a subscription URL from x-ui." -ForegroundColor Yellow
  Write-Host "You can still generate a pack without links, but it won't be copy/paste ready." -ForegroundColor Yellow
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("iOS setup (x-ui / XRay, VLESS Reality)")
$lines.Add("")
$lines.Add("1) Install a client app (free options):")
$lines.Add("- Hiddify (App Store): https://apps.apple.com/app/id6596777532")
$lines.Add("- Karing (App Store): https://apps.apple.com/app/karing/id6472431552")
$lines.Add("- sing-box VT (App Store): https://apps.apple.com/app/sing-box-vt/id6673731168")
$lines.Add("")
$lines.Add("2) Import config:")
if ($SubscriptionUrl) {
  $lines.Add("- Preferred: add subscription URL in the app:")
  $lines.Add("  $SubscriptionUrl")
}
if ($VlessLink) {
  $lines.Add("- Or import a single VLESS link:")
  $lines.Add("  $VlessLink")
}
if (-not $SubscriptionUrl -and -not $VlessLink) {
  $lines.Add("- Copy the vless:// link (or subscription URL) from x-ui and paste it into the app.")
}
$lines.Add("")
$lines.Add("3) Enable device-wide tunnel:")
$lines.Add("- Turn ON VPN/TUN (device-wide) mode in the app")
$lines.Add("- Approve iOS VPN profile installation when prompted")
$lines.Add("")
$lines.Add("Notes:")
$lines.Add("- For VLESS Reality, do not try to enter fields manually. Always use the exported link from x-ui.")
$lines.Add("- If it times out: the inbound TCP port is blocked or not listening on the server.")

try {
  $dir = Split-Path -Parent $OutFile
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $content = ($lines -join "`n") + "`n"
  [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $OutFile), $content, (New-Object System.Text.UTF8Encoding($false)))
} catch {
  # Resolve-Path fails if file does not exist yet; write via raw path
  $content = ($lines -join "`n") + "`n"
  [System.IO.File]::WriteAllText($OutFile, $content, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "Wrote: $OutFile"

