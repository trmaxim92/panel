# Deploy theme + logo from local machine to VPS MikoPBX via git on server
param(
  [string]$HostName = 'root@159.194.248.186',
  [string]$RemoteDir = '/opt/skayscale-pbx'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Push local commits first, then pull+apply on $HostName"

ssh $HostName @"
set -e
if [ ! -d '$RemoteDir/.git' ]; then
  git clone git@github.com:trmaxim92/panel.git '$RemoteDir'
else
  cd '$RemoteDir' && git pull --ff-only
fi
cd '$RemoteDir'
bash deploy-theme.sh
"@

Write-Host "OK — theme deployed on VPS"
