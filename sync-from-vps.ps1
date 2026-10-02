# Pull customized MikoPBX files from production VPS into .\overlay
param(
  [string]$HostName = '159.194.248.186',
  [string]$User = 'root',
  [string]$Container = 'mikopbx'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PullDir = Join-Path $Root '_pull'
New-Item -ItemType Directory -Force -Path $PullDir | Out-Null

$scriptLocal = Join-Path $Root 'sync-pull-overlay.sh'
$c = [IO.File]::ReadAllText($scriptLocal) -replace "`r`n", "`n"
[IO.File]::WriteAllText($scriptLocal, $c, [Text.UTF8Encoding]::new($false))

Write-Host "Upload packer script..."
scp -o ConnectTimeout=20 $scriptLocal "${User}@${HostName}:/tmp/sync-pull-overlay.sh"
Write-Host "Build overlay on VPS..."
ssh -o ConnectTimeout=20 "${User}@${HostName}" "docker cp /tmp/sync-pull-overlay.sh ${Container}:/tmp/sync-pull-overlay.sh; docker exec ${Container} sh /tmp/sync-pull-overlay.sh; docker cp ${Container}:/tmp/mikopbx-overlay.tgz /tmp/mikopbx-overlay.tgz"
$tgz = Join-Path $PullDir 'mikopbx-overlay.tgz'
Write-Host "Download..."
scp -o ConnectTimeout=30 "${User}@${HostName}:/tmp/mikopbx-overlay.tgz" $tgz

$extract = Join-Path $PullDir 'mikopbx-overlay'
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
tar -xzf $tgz -C $PullDir

$dest = Join-Path $Root 'overlay'
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Move-Item $extract $dest

# Keep patch sources in sync with live
$patches = Join-Path $Root 'theme\cdr-patches'
Copy-Item -Force (Join-Path $dest 'usr\www\src\PBXCoreREST\Lib\Cdr\GetListAction.php') (Join-Path $patches 'GetListAction.php')
Copy-Item -Force (Join-Path $dest 'usr\www\src\AdminCabinet\Views\CallDetailRecords\index.volt') (Join-Path $patches 'index.volt')
Copy-Item -Force (Join-Path $dest 'usr\www\sites\admin-cabinet\assets\js\src\CallDetailRecords\call-detail-records-index.js') (Join-Path $patches 'call-detail-records-index.src.js')

Write-Host "OK: overlay refreshed at $dest"
Get-Content (Join-Path $dest 'META.txt')
