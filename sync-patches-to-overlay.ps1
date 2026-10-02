# Sync editable sources from theme/ into overlay/ (source of deploy)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$P = Join-Path $Root 'theme\cdr-patches'
$O = Join-Path $Root 'overlay\usr\www'
$L = Join-Path $Root 'theme\layout-patches'
$E = Join-Path $Root 'theme\extensions-patches'
$D = Join-Path $Root 'theme\dashboard-patches'

# CDR API
$dstApi = Join-Path $O 'src\PBXCoreREST\Lib\Cdr'
New-Item -ItemType Directory -Force -Path $dstApi | Out-Null
Copy-Item -Force (Join-Path $P 'GetListAction.php') (Join-Path $dstApi 'GetListAction.php')

# CDR view
$dstView = Join-Path $O 'src\AdminCabinet\Views\CallDetailRecords'
New-Item -ItemType Directory -Force -Path $dstView | Out-Null
Copy-Item -Force (Join-Path $P 'index.volt') (Join-Path $dstView 'index.volt')

# CDR JS (src + pbx ss2 name used in AssetProvider)
$jsSrc = Join-Path $O 'sites\admin-cabinet\assets\js\src\CallDetailRecords'
$jsPbx = Join-Path $O 'sites\admin-cabinet\assets\js\pbx\CallDetailRecords'
New-Item -ItemType Directory -Force -Path $jsSrc,$jsPbx | Out-Null
$js = Join-Path $P 'call-detail-records-index.src.js'
Copy-Item -Force $js (Join-Path $jsSrc 'call-detail-records-index.js')
Copy-Item -Force $js (Join-Path $jsPbx 'call-detail-records-index.js')
Copy-Item -Force $js (Join-Path $jsPbx 'call-detail-records-index.ss.js')
Copy-Item -Force $js (Join-Path $jsPbx 'call-detail-records-index.ss2.js')
Copy-Item -Force $js (Join-Path $P 'call-detail-records-index.pbx.js')

# Call recordings
$cr = Join-Path $P 'call-recordings'
Copy-Item -Force (Join-Path $cr 'CallRecordingsController.php') (Join-Path $O 'src\AdminCabinet\Controllers\CallRecordingsController.php')
$crView = Join-Path $O 'src\AdminCabinet\Views\CallRecordings'
New-Item -ItemType Directory -Force -Path $crView | Out-Null
Copy-Item -Force (Join-Path $cr 'index.volt') (Join-Path $crView 'index.volt')
$crJs = Join-Path $O 'sites\admin-cabinet\assets\js\pbx\CallRecordings'
New-Item -ItemType Directory -Force -Path $crJs | Out-Null
Copy-Item -Force (Join-Path $cr 'call-recordings-index.js') (Join-Path $crJs 'call-recordings-index.js')
$crCss = Join-Path $O 'sites\admin-cabinet\assets\css\CallRecordings'
New-Item -ItemType Directory -Force -Path $crCss | Out-Null
Copy-Item -Force (Join-Path $cr 'call-recordings.css') (Join-Path $crCss 'call-recordings.css')

# SkyScale STT settings
$stt = Join-Path $Root 'theme\stt-patches'
if (Test-Path $stt) {
  Copy-Item -Force (Join-Path $stt 'SkyscaleSttController.php') (Join-Path $O 'src\AdminCabinet\Controllers\SkyscaleSttController.php')
  $sttView = Join-Path $O 'src\AdminCabinet\Views\SkyscaleStt'
  New-Item -ItemType Directory -Force -Path $sttView | Out-Null
  if (Test-Path (Join-Path $stt 'views\index.volt')) {
    Copy-Item -Force (Join-Path $stt 'views\index.volt') (Join-Path $sttView 'index.volt')
  }
  $sttCss = Join-Path $O 'sites\admin-cabinet\assets\css\SkyscaleStt'
  New-Item -ItemType Directory -Force -Path $sttCss | Out-Null
  if (Test-Path (Join-Path $stt 'skyscale-stt.css')) {
    Copy-Item -Force (Join-Path $stt 'skyscale-stt.css') (Join-Path $sttCss 'skyscale-stt.css')
  }
}

# ATC Dashboard
Copy-Item -Force (Join-Path $D 'DashboardController.php') (Join-Path $O 'src\AdminCabinet\Controllers\DashboardController.php')
$dashView = Join-Path $O 'src\AdminCabinet\Views\Dashboard'
New-Item -ItemType Directory -Force -Path $dashView | Out-Null
Copy-Item -Force (Join-Path $D 'index.volt') (Join-Path $dashView 'index.volt')
$dashJs = Join-Path $O 'sites\admin-cabinet\assets\js\pbx\Dashboard'
New-Item -ItemType Directory -Force -Path $dashJs | Out-Null
Copy-Item -Force (Join-Path $D 'dashboard-index.js') (Join-Path $dashJs 'dashboard-index.js')
$dashCss = Join-Path $O 'sites\admin-cabinet\assets\css\Dashboard'
New-Item -ItemType Directory -Force -Path $dashCss | Out-Null
Copy-Item -Force (Join-Path $D 'dashboard.css') (Join-Path $dashCss 'dashboard.css')

# Layout partials (shell redesign)
$partials = Join-Path $O 'src\AdminCabinet\Views\partials'
New-Item -ItemType Directory -Force -Path $partials | Out-Null
@(
  'leftsidebar.volt',
  'topMenu.volt',
  'mainHeader.volt',
  'modulesHeader.volt',
  'emptyTablePlaceholder.volt',
  'tablesbuttons.volt'
) | ForEach-Object {
  $src = Join-Path $L $_
  if (Test-Path $src) {
    Copy-Item -Force $src (Join-Path $partials $_)
  }
}

# Extensions (Employees)
$extView = Join-Path $O 'src\AdminCabinet\Views\Extensions'
New-Item -ItemType Directory -Force -Path $extView | Out-Null
if (Test-Path (Join-Path $E 'index.volt')) {
  Copy-Item -Force (Join-Path $E 'index.volt') (Join-Path $extView 'index.volt')
}

Write-Host "OK: theme patches -> overlay"
