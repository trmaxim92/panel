# Restore prod cf + storage (CDR) from mikopbx-migrate.tgz into local Docker volumes
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$tgz = Join-Path $PSScriptRoot 'mikopbx-migrate.tgz'
$extract = Join-Path $PSScriptRoot 'migrate'
$dataDir = Join-Path $extract 'mikopbx-migrate\data'

if (-not (Test-Path $tgz)) {
  Write-Host "Missing $tgz"
  Write-Host "Download: scp root@159.194.248.186:/tmp/mikopbx-migrate.tgz ."
  exit 1
}

if (-not (Test-Path (Join-Path $dataDir 'cf.tgz'))) {
  Write-Host "==> Extracting mikopbx-migrate.tgz..."
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  tar -xzf $tgz -C $extract
}

$cfVol = 'mikopbx_mikopbx_cf'
$stVol = 'mikopbx_mikopbx_storage'
$dataMount = ($dataDir -replace '\\', '/')

Write-Host "==> Stopping mikopbx-dev..."
docker compose -f docker-compose.dev.yml stop

Write-Host "==> Restoring cf + storage into volumes..."
docker run --rm `
  -v "${cfVol}:/cf" `
  -v "${stVol}:/storage" `
  -v "${dataMount}:/backup:ro" `
  alpine:3.20 sh -c @'
set -e
apk add --no-cache tar >/dev/null
rm -rf /cf/* /cf/.[!.]* 2>/dev/null || true
mkdir -p /tmp/cfrest
tar -C /tmp/cfrest -xzf /backup/cf.tgz
cp -a /tmp/cfrest/cf/. /cf/
rm -rf /storage/* /storage/.[!.]* 2>/dev/null || true
tar -C /storage -xzf /backup/storage-nologs.tgz
echo "cf files:" $(ls /cf/conf | wc -l)
echo "cdr.db:" $(ls -lah /storage/usbdisk1/mikopbx/astlogs/asterisk/cdr.db)
'@

Write-Host "==> Starting mikopbx-dev..."
docker compose -f docker-compose.dev.yml up -d

Write-Host "==> Waiting for boot..."
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 3
  $logs = docker logs mikopbx-dev 2>&1 | Out-String
  if ($logs -match 'fully loaded welcome|Web Interface Access') {
    $ok = $true
    break
  }
  Write-Host "  ... ($i)"
}

Write-Host "==> CDR row check..."
docker exec mikopbx-dev sh -c "sqlite3 /storage/usbdisk1/mikopbx/astlogs/asterisk/cdr.db 'SELECT COUNT(*) FROM cdr_general;' 2>/dev/null || php -r \"\\\$db=new SQLite3('/storage/usbdisk1/mikopbx/astlogs/asterisk/cdr.db'); echo \\\$db->querySingle('SELECT COUNT(*) FROM cdr_general');\""

Write-Host ""
Write-Host "OK. Open https://127.0.0.1:18443 and Ctrl+F5"
Write-Host "After first restore: .\\dev-apply-overlay.ps1"
Write-Host "Login uses restored production admin password from cf."
Write-Host "Re-apply UI patches: .\\dev-apply-overlay.ps1"
