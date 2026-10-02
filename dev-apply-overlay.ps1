# Apply overlay + theme into local mikopbx-dev container for testing
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

& "$PSScriptRoot\sync-patches-to-overlay.ps1"

$name = 'mikopbx-dev'
$running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$name$"
if (-not $running) {
  Write-Host "Container $name is not running. Start with .\dev-up.ps1"
  exit 1
}

Write-Host "==> Copy overlay to $name..."
docker cp ".\overlay\usr\www\." "${name}:/usr/www/"

Write-Host "==> Apply theme CSS..."
docker cp ".\theme\skyscale-theme.css" "${name}:/tmp/skyscale-theme.css"
docker cp ".\theme\cdr-patches\cdr-filters.css" "${name}:/tmp/cdr-filters.css"
docker cp ".\theme\cdr-patches" "${name}:/tmp/cdr-patches"
docker cp ".\theme\layout-patches" "${name}:/tmp/layout-patches"
docker cp ".\theme\extensions-patches" "${name}:/tmp/extensions-patches"
docker cp ".\theme\dashboard-patches" "${name}:/tmp/dashboard-patches"
if (Test-Path ".\theme\monitor-patches") {
  docker cp ".\theme\monitor-patches" "${name}:/tmp/monitor-patches"
}
if (Test-Path ".\theme\stt-patches") {
  docker cp ".\theme\stt-patches" "${name}:/tmp/stt-patches"
}
docker cp ".\theme\apply-in-container.sh" "${name}:/tmp/apply-in-container.sh"
if (Test-Path ".\theme\clear-localisation-cache.sh") {
  docker cp ".\theme\clear-localisation-cache.sh" "${name}:/tmp/clear-localisation-cache.sh"
}
docker exec $name sh -c "THEME_SRC=/tmp/skyscale-theme.css sh /tmp/apply-in-container.sh"

# append cdr-filters into custom.css markers if script doesn't
docker exec $name sh -c "rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null; true"
docker cp ".\migrate\_opcache.php" "${name}:/tmp/_opcache.php" 2>$null
if (Test-Path ".\migrate\_opcache.php") {
  docker exec $name php /tmp/_opcache.php
} else {
  docker exec $name php -r "echo 'skip opcache\n';"
}

# CRITICAL: CDR API runs in long-lived WorkerApiCommands — must restart or PHP patches stay invisible
Write-Host "==> Restart WorkerApiCommands..."
docker cp ".\migrate\_fix_workers2.sh" "${name}:/tmp/_fix_workers2.sh"
docker exec $name sh /tmp/_fix_workers2.sh

Write-Host ""
Write-Host "OK. Open https://127.0.0.1:18443/admin-cabinet/call-detail-records/index and Ctrl+F5, then Показать"
