# Local MikoPBX (Windows) — start, apply theme, open browser
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Checking Docker..."
docker info | Out-Null

$env:WEB_ADMIN_PASSWORD = if ($env:WEB_ADMIN_PASSWORD) { $env:WEB_ADMIN_PASSWORD } else { 'admin' }

Write-Host "==> Pull + up (docker-compose.dev.yml)..."
docker compose -f docker-compose.dev.yml pull
docker compose -f docker-compose.dev.yml up -d

Write-Host "==> Waiting for Miko to boot (up to ~120s)..."
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 3
  $logs = docker logs mikopbx-dev 2>&1 | Out-String
  if ($logs -match 'fully loaded welcome|Web Interface Access') {
    $ok = $true
    break
  }
  $st = docker inspect -f '{{.State.Status}}' mikopbx-dev 2>$null
  Write-Host "  ... status=$st ($i)"
}

Write-Host "==> Applying SkyScale theme..."
docker cp .\theme\skyscale-theme.css "mikopbx-dev:/tmp/skyscale-theme.css"
docker cp .\theme\apply-in-container.sh "mikopbx-dev:/tmp/apply-in-container.sh"
docker exec mikopbx-dev sh -c "mkdir -p /theme; cp /tmp/skyscale-theme.css /tmp/theme-skyscale.css; THEME_SRC=/tmp/skyscale-theme.css sh /tmp/apply-in-container.sh"

Write-Host ""
Write-Host "========================================"
Write-Host " Local Miko:  https://127.0.0.1:18443"
Write-Host "              http://127.0.0.1:18080"
Write-Host " Login:       admin"
Write-Host " Password:    $env:WEB_ADMIN_PASSWORD"
Write-Host " Theme CSS:   mikopbx\theme\skyscale-theme.css"
Write-Host " After CSS edit: .\dev-apply-theme.ps1"
Write-Host " Deploy to VPS:  .\deploy-theme.ps1"
Write-Host "========================================"

Start-Process "https://127.0.0.1:18443"
