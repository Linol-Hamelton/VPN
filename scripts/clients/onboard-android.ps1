param(
  [Parameter(Mandatory=$false)]
  [string]$VlessLink,

  [Parameter(Mandatory=$false)]
  [string]$SubscriptionUrl,

  [Parameter(Mandatory=$false)]
  [string]$OutFile = ".\\client-pack-android.txt"
)

if (-not $VlessLink -and -not $SubscriptionUrl) {
  Write-Host "Tip: paste a vless:// link OR a subscription URL from x-ui." -ForegroundColor Yellow
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Android setup (x-ui / XRay, VLESS Reality)")
$lines.Add("")
$lines.Add("1) Install a client app (pick one):")
$lines.Add("- Hiddify (Android)")
$lines.Add("- v2rayNG")
$lines.Add("- NekoBox / sing-box based clients")
$lines.Add("")
$lines.Add("2) Import config:")
if ($SubscriptionUrl) {
  $lines.Add("- Preferred: add subscription URL:")
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
$lines.Add("3) Enable VPN mode and connect.")
$lines.Add("")
$lines.Add("Notes:")
$lines.Add("- If it times out: the inbound TCP port is blocked or not listening on the server.")

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($OutFile, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Wrote: $OutFile"

