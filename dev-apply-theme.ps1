# Re-apply local theme + logo after editing brand assets
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

docker cp .\theme\skyscale-theme.css "mikopbx-dev:/tmp/skyscale-theme.css"
docker cp .\theme\brand "mikopbx-dev:/tmp/brand"
docker cp .\theme\apply-in-container.sh "mikopbx-dev:/tmp/apply-in-container.sh"
docker exec mikopbx-dev sh -c "THEME_SRC=/tmp/skyscale-theme.css BRAND_DIR=/tmp/brand sh /tmp/apply-in-container.sh"
Write-Host "OK - refresh Ctrl+F5 https://127.0.0.1:18443"
