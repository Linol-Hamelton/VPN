param(
  [Parameter(Mandatory=$false)]
  [string]$VlessLink,

  [Parameter(Mandatory=$false)]
  [string]$SubscriptionUrl,

  [Parameter(Mandatory=$false)]
  [string]$OutFile = ".\\client-pack-windows.txt"
)

if (-not $VlessLink -and -not $SubscriptionUrl) {
  Write-Host "Tip: paste a vless:// link OR a subscription URL from x-ui." -ForegroundColor Yellow
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Windows setup (x-ui / XRay, VLESS Reality)")
$lines.Add("")
$lines.Add("1) Install a client app (recommended):")
$lines.Add("- v2rayN (Windows)")
$lines.Add("")
$lines.Add("2) Import config:")
if ($SubscriptionUrl) {
  $lines.Add("- Preferred: add subscription URL in v2rayN:")
  $lines.Add("  $SubscriptionUrl")
}
if ($VlessLink) {
  $lines.Add("- Or import a single VLESS link:")
  $lines.Add("  $VlessLink")
}
if (-not $SubscriptionUrl -and -not $VlessLink) {
  $lines.Add("- Copy the vless:// link (or subscription URL) from x-ui and import it into v2rayN.")
}
$lines.Add("")
$lines.Add("3) Connect:")
$lines.Add("- Select the imported profile (Configuration) and connect.")
$lines.Add("- If you want device-wide tunneling, enable TUN mode (if you use it).")
$lines.Add("")
$lines.Add("Notes:")
$lines.Add("- If it times out: the inbound TCP port is blocked or not listening on the server.")

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($OutFile, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Wrote: $OutFile"

