#!/bin/sh
# Apply SkyScale theme + logo inside running Miko container (dev or prod)
set -e

CSSDIR=/offload/rootfs/usr/www/sites/admin-cabinet/assets/css
IMGDIR=/offload/rootfs/usr/www/sites/admin-cabinet/assets/img
FONTDIR=/offload/rootfs/usr/www/sites/admin-cabinet/assets/fonts
CSS=$CSSDIR/custom.css
THEME_SRC=${THEME_SRC:-/theme/skyscale-theme.css}
BRAND_DIR=${BRAND_DIR:-/theme/brand}

if [ ! -f "$THEME_SRC" ]; then
  THEME_SRC=/tmp/skyscale-theme.css
fi

if [ ! -f "$THEME_SRC" ]; then
  THEME_SRC=$CSSDIR/skyscale-theme.css
fi

if [ ! -f "$THEME_SRC" ]; then
  echo "Theme file not found" >&2
  exit 1
fi

mkdir -p "$FONTDIR" "$IMGDIR"

# --- Logo ---
LOGO_SVG=
if [ -f "$BRAND_DIR/logo-mikopbx.svg" ]; then
  LOGO_SVG="$BRAND_DIR/logo-mikopbx.svg"
elif [ -f /tmp/logo-mikopbx.svg ]; then
  LOGO_SVG=/tmp/logo-mikopbx.svg
fi

if [ -n "$LOGO_SVG" ]; then
  cp "$LOGO_SVG" "$IMGDIR/logo-mikopbx.svg"
  cp "$LOGO_SVG" "$IMGDIR/logo.svg"
  echo "Logo SVG installed"
fi

if [ -f "$BRAND_DIR/logo-skayskel.png" ]; then
  cp "$BRAND_DIR/logo-skayskel.png" "$IMGDIR/logo-skayskel.png"
  cp "$BRAND_DIR/logo-skayskel.png" "$IMGDIR/logo-mikopbx.png"
  cp "$BRAND_DIR/logo-skayskel.png" "$IMGDIR/logo.png"
elif [ -f /tmp/logo-skayskel.png ]; then
  cp /tmp/logo-skayskel.png "$IMGDIR/logo-skayskel.png"
  cp /tmp/logo-skayskel.png "$IMGDIR/logo-mikopbx.png"
  cp /tmp/logo-skayskel.png "$IMGDIR/logo.png"
fi

# SVG-as-<img> cannot reliably render nested PNG; force PNG path in controller
CTRL=/usr/www/src/AdminCabinet/Controllers/BaseController.php
if [ -f "$CTRL" ]; then
  sed -i 's|assets/img/logo-mikopbx.svg|assets/img/logo-mikopbx.png|g' "$CTRL"
fi

if [ -f "$BRAND_DIR/favicon.png" ]; then
  cp "$BRAND_DIR/favicon.png" "$IMGDIR/favicon.png"
  cp "$BRAND_DIR/favicon.png" "$IMGDIR/favicon-32x32.png"
fi

if [ -f "$BRAND_DIR/brand-icon.png" ]; then
  cp "$BRAND_DIR/brand-icon.png" "$IMGDIR/android-chrome-192x192.png"
  cp "$BRAND_DIR/brand-icon.png" "$IMGDIR/apple-touch-icon.png"
fi

# --- Theme CSS ---
cp "$THEME_SRC" "$CSSDIR/skyscale-theme.css"

# Strip any previous SkyScale injection (marked block OR legacy unmarked paste)
if grep -qE 'ss-theme-begin|SkyScale theme|ss-hover-fix|СкайСкейл' "$CSS"; then
  awk '/ss-theme-begin|\/\* SkyScale|\/\* СкайСкейл|\/\* ss-hover-fix/{exit} {print}' "$CSS" > /tmp/custom.css.base
else
  cp "$CSS" /tmp/custom.css.base
fi

cp /tmp/custom.css.base "$CSS"

{
  echo ''
  echo '/* ss-theme-begin */'
  cat "$CSSDIR/skyscale-theme.css"
  echo '/* ss-theme-end */'
} >> "$CSS"

echo "Theme applied to $CSS"
ls -la "$IMGDIR/logo-mikopbx.svg" "$IMGDIR/logo.svg" 2>/dev/null || true

# --- CDR UI patch: status / wait / talk columns ---
CDR_JS_PBX=/offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/CallDetailRecords/call-detail-records-index.js
CDR_JS_SRC=/offload/rootfs/usr/www/sites/admin-cabinet/assets/js/src/CallDetailRecords/call-detail-records-index.js
CDR_VOLT=/usr/www/src/AdminCabinet/Views/CallDetailRecords/index.volt
CDR_PATCH_DIR=
if [ -d "$BRAND_DIR/../cdr-patches" ]; then
  CDR_PATCH_DIR="$BRAND_DIR/../cdr-patches"
elif [ -d /theme/cdr-patches ]; then
  CDR_PATCH_DIR=/theme/cdr-patches
elif [ -d /tmp/cdr-patches ]; then
  CDR_PATCH_DIR=/tmp/cdr-patches
fi
if [ -n "$CDR_PATCH_DIR" ]; then
  if [ -f "$CDR_PATCH_DIR/call-detail-records-index.pbx.js" ]; then
    cp "$CDR_PATCH_DIR/call-detail-records-index.pbx.js" "$CDR_JS_PBX"
    echo "CDR pbx JS patched (status/wait/talk columns)"
  fi
  if [ -f "$CDR_PATCH_DIR/call-detail-records-index.src.js" ]; then
    cp "$CDR_PATCH_DIR/call-detail-records-index.src.js" "$CDR_JS_SRC"
    echo "CDR src JS patched"
  fi
  if [ -f "$CDR_PATCH_DIR/index.volt" ]; then
    cp "$CDR_PATCH_DIR/index.volt" "$CDR_VOLT"
    rm -rf /storage/usbdisk1/mikopbx/tmp/volt 2>/dev/null || true
    echo "CDR volt patched"
  fi
  if [ -f "$CDR_PATCH_DIR/GetListAction.php" ]; then
    cp "$CDR_PATCH_DIR/GetListAction.php" /usr/www/src/PBXCoreREST/Lib/Cdr/GetListAction.php
    echo "CDR GetListAction patched (billsecMin)"
  fi
  if [ -f "$CDR_PATCH_DIR/cdr-filters.css" ]; then
    # Append/refresh CDR panel styles inside custom.css
    if grep -q 'ss-cdr-panel-begin' "$CSS"; then
      awk '/ss-cdr-panel-begin/{exit} {print}' "$CSS" > /tmp/custom.css.nocdr
      cp /tmp/custom.css.nocdr "$CSS"
    fi
    {
      echo ''
      echo '/* ss-cdr-panel-begin */'
      cat "$CDR_PATCH_DIR/cdr-filters.css"
      echo '/* ss-cdr-panel-end */'
    } >> "$CSS"
    echo "CDR filters CSS patched"
  fi
fi

# --- Layout shell patches ---
LAYOUT_DIR=
if [ -d "$BRAND_DIR/../layout-patches" ]; then
  LAYOUT_DIR="$BRAND_DIR/../layout-patches"
elif [ -d /theme/layout-patches ]; then
  LAYOUT_DIR=/theme/layout-patches
elif [ -d /tmp/layout-patches ]; then
  LAYOUT_DIR=/tmp/layout-patches
fi
PARTIALS=/usr/www/src/AdminCabinet/Views/partials
OFF_PARTIALS=/offload/rootfs/usr/www/src/AdminCabinet/Views/partials
if [ -n "$LAYOUT_DIR" ] && [ -d "$PARTIALS" ]; then
  mkdir -p "$OFF_PARTIALS"
  for f in leftsidebar.volt topMenu.volt mainHeader.volt modulesHeader.volt emptyTablePlaceholder.volt tablesbuttons.volt; do
    if [ -f "$LAYOUT_DIR/$f" ]; then
      cp "$LAYOUT_DIR/$f" "$PARTIALS/$f"
      cp "$LAYOUT_DIR/$f" "$OFF_PARTIALS/$f" 2>/dev/null || true
    fi
  done
  echo "Layout partials patched"
fi

# --- Active Calls monitor (ModuleMonitorActiveCalls) ---
MON_DIR=
if [ -d "$BRAND_DIR/../monitor-patches" ]; then
  MON_DIR="$BRAND_DIR/../monitor-patches"
elif [ -d /theme/monitor-patches ]; then
  MON_DIR=/theme/monitor-patches
elif [ -d /tmp/monitor-patches ]; then
  MON_DIR=/tmp/monitor-patches
fi
if [ -n "$MON_DIR" ] && [ -d "$MON_DIR" ]; then
  MON_MOD=/storage/usbdisk1/mikopbx/custom_modules/ModuleMonitorActiveCalls
  if [ -f "$MON_MOD/App/Controllers/ModuleMonitorActiveCallsController.php" ]; then
    # Strip vendor logo from module header
    sed -i 's|$this->view->logoImagePath = .*|$this->view->logoImagePath = '"''"';|' \
      "$MON_MOD/App/Controllers/ModuleMonitorActiveCallsController.php" 2>/dev/null || true
  fi
  # Inject CSS into custom.css
  if [ -f "$MON_DIR/monitor-active-calls.css" ] && [ -f "$CSS" ]; then
    if grep -q 'ss-monitor-page-begin' "$CSS"; then
      awk '/ss-monitor-page-begin/{exit} {print}' "$CSS" > /tmp/custom.css.nomon
      cp /tmp/custom.css.nomon "$CSS"
    fi
    {
      echo ''
      echo '/* ss-monitor-page-begin */'
      cat "$MON_DIR/monitor-active-calls.css"
      echo '/* ss-monitor-page-end */'
    } >> "$CSS"
    # Also refresh module CSS cache copy
    mkdir -p "$MON_MOD/public/assets/css" \
             /usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls \
             /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls
    {
      cat "$MON_MOD/public/assets/css/module-monitor-active-calls.css" 2>/dev/null || true
      echo ''
      echo '/* ss-monitor-page-begin */'
      cat "$MON_DIR/monitor-active-calls.css"
      echo '/* ss-monitor-page-end */'
    } > /tmp/module-monitor-active-calls.css.merged
    # Keep original module css + our overrides in cache path used by AssetManager
    if [ -f "$MON_DIR/monitor-active-calls.css" ]; then
      cat "$MON_DIR/monitor-active-calls.css" > /usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls/module-monitor-active-calls.css 2>/dev/null || true
      # Prefer appending overrides onto original module stylesheet in cache
      if [ -f "$MON_MOD/public/assets/css/module-monitor-active-calls.css" ]; then
        {
          cat "$MON_MOD/public/assets/css/module-monitor-active-calls.css"
          echo ''
          cat "$MON_DIR/monitor-active-calls.css"
        } > /usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls/module-monitor-active-calls.css
        cp /usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls/module-monitor-active-calls.css \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/cache/ModuleMonitorActiveCalls/module-monitor-active-calls.css 2>/dev/null || true
      fi
    fi
  fi
  if [ -f "$MON_DIR/monitor-active-calls.js" ]; then
    mkdir -p /usr/www/sites/admin-cabinet/assets/js/pbx/ModuleMonitorActiveCalls \
             /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/ModuleMonitorActiveCalls
    cp "$MON_DIR/monitor-active-calls.js" /usr/www/sites/admin-cabinet/assets/js/pbx/ModuleMonitorActiveCalls/monitor-active-calls.js
    cp "$MON_DIR/monitor-active-calls.js" /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/ModuleMonitorActiveCalls/monitor-active-calls.js 2>/dev/null || true
    # IMPORTANT: js/cache/ModuleMonitorActiveCalls/* is the module public file (symlink/bind).
    # Never overwrite it — boot JS is loaded from modulesHeader.volt instead.
  fi
  find /usr/www/sites/admin-cabinet/assets/js/cache -type f \( -name '*-footer.js' -o -name '*-header.js' \) -delete 2>/dev/null || true
  echo "Active Calls monitor patched"
fi

# --- Extensions (Employees) page ---
EXT_DIR=
if [ -d "$BRAND_DIR/../extensions-patches" ]; then
  EXT_DIR="$BRAND_DIR/../extensions-patches"
elif [ -d /theme/extensions-patches ]; then
  EXT_DIR=/theme/extensions-patches
elif [ -d /tmp/extensions-patches ]; then
  EXT_DIR=/tmp/extensions-patches
fi
EXT_VIEW=/usr/www/src/AdminCabinet/Views/Extensions
OFF_EXT=/offload/rootfs/usr/www/src/AdminCabinet/Views/Extensions
if [ -n "$EXT_DIR" ] && [ -f "$EXT_DIR/index.volt" ]; then
  mkdir -p "$EXT_VIEW" "$OFF_EXT"
  cp "$EXT_DIR/index.volt" "$EXT_VIEW/index.volt"
  cp "$EXT_DIR/index.volt" "$OFF_EXT/index.volt" 2>/dev/null || true
  echo "Extensions index patched"
fi

# Call recordings volt/js/css if present in cdr-patches
if [ -n "$CDR_PATCH_DIR" ] && [ -d "$CDR_PATCH_DIR/call-recordings" ]; then
  CR="$CDR_PATCH_DIR/call-recordings"
  mkdir -p /usr/www/src/AdminCabinet/Controllers \
           /usr/www/src/AdminCabinet/Views/CallRecordings \
           /usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings \
           /usr/www/sites/admin-cabinet/assets/css/CallRecordings \
           /offload/rootfs/usr/www/src/AdminCabinet/Controllers \
           /offload/rootfs/usr/www/src/AdminCabinet/Views/CallRecordings \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/CallRecordings
  [ -f "$CR/CallRecordingsController.php" ] && cp "$CR/CallRecordingsController.php" /usr/www/src/AdminCabinet/Controllers/CallRecordingsController.php
  [ -f "$CR/CallRecordingsController.php" ] && cp "$CR/CallRecordingsController.php" /offload/rootfs/usr/www/src/AdminCabinet/Controllers/CallRecordingsController.php 2>/dev/null || true
  [ -f "$CR/index.volt" ] && cp "$CR/index.volt" /usr/www/src/AdminCabinet/Views/CallRecordings/index.volt
  [ -f "$CR/index.volt" ] && cp "$CR/index.volt" /offload/rootfs/usr/www/src/AdminCabinet/Views/CallRecordings/index.volt 2>/dev/null || true
  [ -f "$CR/call-recordings-index.js" ] && cp "$CR/call-recordings-index.js" /usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings/call-recordings-index.js
  [ -f "$CR/call-recordings-index.js" ] && cp "$CR/call-recordings-index.js" /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings/call-recordings-index.js
  [ -f "$CR/call-recordings.css" ] && cp "$CR/call-recordings.css" /usr/www/sites/admin-cabinet/assets/css/CallRecordings/call-recordings.css
  [ -f "$CR/call-recordings.css" ] && cp "$CR/call-recordings.css" /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/CallRecordings/call-recordings.css
  # Inject into custom.css so styles apply even if AssetManager cache lags
  if [ -f "$CR/call-recordings.css" ] && [ -f "$CSS" ]; then
    if grep -q 'ss-rec-page-begin' "$CSS"; then
      awk '/ss-rec-page-begin/{exit} {print}' "$CSS" > /tmp/custom.css.norec
      cp /tmp/custom.css.norec "$CSS"
    fi
    {
      echo ''
      echo '/* ss-rec-page-begin */'
      cat "$CR/call-recordings.css"
      echo '/* ss-rec-page-end */'
    } >> "$CSS"
  fi
  echo "Call recordings patched"
fi

# --- Local Whisper / ModuleCloudSpeechToText provider patches ---
STT_DIR=
if [ -d "$BRAND_DIR/../stt-patches" ]; then
  STT_DIR="$BRAND_DIR/../stt-patches"
elif [ -d /theme/stt-patches ]; then
  STT_DIR=/theme/stt-patches
elif [ -d /tmp/stt-patches ]; then
  STT_DIR=/tmp/stt-patches
fi
STT_MOD=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText
if [ -n "$STT_DIR" ] && [ -d "$STT_MOD" ]; then
  mkdir -p "$STT_MOD/Lib/SpeechMikoLabV1" "$STT_MOD/Lib/Processing" "$STT_MOD/db/private"
  [ -f "$STT_DIR/SkyscaleProviderConfig.php" ] && cp "$STT_DIR/SkyscaleProviderConfig.php" "$STT_MOD/Lib/SkyscaleProviderConfig.php"
  [ -f "$STT_DIR/LocalWhisperAdapter.php" ] && cp "$STT_DIR/LocalWhisperAdapter.php" "$STT_MOD/Lib/SpeechMikoLabV1/LocalWhisperAdapter.php"
  if [ -f "$STT_DIR/ProductionProcessingRuntimeFactory.php" ]; then
    # Backup once, then overlay factory
    if [ ! -f "$STT_MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php.skyscale-bak" ] \
       && [ -f "$STT_MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php" ]; then
      cp "$STT_MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php" \
         "$STT_MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php.skyscale-bak"
    fi
    cp "$STT_DIR/ProductionProcessingRuntimeFactory.php" "$STT_MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php"
    # Guard against UTF-16 copies from Windows hosts
    python3 - <<'PY'
from pathlib import Path
p = Path("/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/Lib/Processing/ProductionProcessingRuntimeFactory.php")
b = p.read_bytes()
if len(b) >= 4 and b[0] == 0x3C and b[1] == 0x00:
    p.write_bytes(b.decode("utf-16-le").encode("utf-8"))
    print("converted factory UTF-16 -> UTF-8")
PY
  fi

  # SkyScale STT settings page (AdminCabinet)
  mkdir -p /usr/www/src/AdminCabinet/Controllers \
           /usr/www/src/AdminCabinet/Views/SkyscaleStt \
           /usr/www/sites/admin-cabinet/assets/css/SkyscaleStt \
           /offload/rootfs/usr/www/src/AdminCabinet/Controllers \
           /offload/rootfs/usr/www/src/AdminCabinet/Views/SkyscaleStt \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/SkyscaleStt
  [ -f "$STT_DIR/SkyscaleSttController.php" ] && cp "$STT_DIR/SkyscaleSttController.php" /usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php
  [ -f "$STT_DIR/SkyscaleSttController.php" ] && cp "$STT_DIR/SkyscaleSttController.php" /offload/rootfs/usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php 2>/dev/null || true
  [ -f "$STT_DIR/views/index.volt" ] && cp "$STT_DIR/views/index.volt" /usr/www/src/AdminCabinet/Views/SkyscaleStt/index.volt
  [ -f "$STT_DIR/views/index.volt" ] && cp "$STT_DIR/views/index.volt" /offload/rootfs/usr/www/src/AdminCabinet/Views/SkyscaleStt/index.volt 2>/dev/null || true
  [ -f "$STT_DIR/skyscale-stt.css" ] && cp "$STT_DIR/skyscale-stt.css" /usr/www/sites/admin-cabinet/assets/css/SkyscaleStt/skyscale-stt.css
  [ -f "$STT_DIR/skyscale-stt.css" ] && cp "$STT_DIR/skyscale-stt.css" /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/SkyscaleStt/skyscale-stt.css 2>/dev/null || true
  if [ -f "$STT_DIR/skyscale-stt.css" ] && [ -f "$CSS" ]; then
    if grep -q 'ss-stt-page-begin' "$CSS"; then
      awk '/ss-stt-page-begin/{exit} {print}' "$CSS" > /tmp/custom.css.nostt
      cp /tmp/custom.css.nostt "$CSS"
    fi
    {
      echo ''
      echo '/* ss-stt-page-begin */'
      cat "$STT_DIR/skyscale-stt.css"
      echo '/* ss-stt-page-end */'
    } >> "$CSS"
  fi

  # Strip Miko logo from Cloud STT module header (same approach as Active Calls)
  if [ -f "$STT_MOD/App/Controllers/ModuleCloudSpeechToTextController.php" ]; then
    sed -i 's|$this->view->logoImagePath = .*|$this->view->logoImagePath = '"''"';|' \
      "$STT_MOD/App/Controllers/ModuleCloudSpeechToTextController.php" 2>/dev/null || true
  fi

  # In-page transcript modal on Call Recordings (do not navigate to the STT module)
  if [ -f "$STT_DIR/patch-cdr-modal-on-recordings.sh" ]; then
    sh "$STT_DIR/patch-cdr-modal-on-recordings.sh" || true
  fi

  # Install / start faster-whisper sidecar
  if [ -f "$STT_DIR/whisper-sidecar/install-in-container.sh" ]; then
    sh "$STT_DIR/whisper-sidecar/install-in-container.sh" "$STT_DIR" || true
  fi
  if [ -f "$STT_MOD/db/private/skyscale-provider.json" ]; then
    chown www:disk "$STT_MOD/db/private/skyscale-provider.json" 2>/dev/null || true
    chmod 664 "$STT_MOD/db/private/skyscale-provider.json" 2>/dev/null || true
  fi

  # Keep-alive helper (best-effort; never abort theme apply)
  ENSURE="$STT_MOD/db/private/whisper-sidecar/ensure-running.sh"
  if [ -x "$ENSURE" ]; then
    mkdir -p /usr/local/bin 2>/dev/null || true
    if [ -d /usr/local/bin ]; then
      cat > /usr/local/bin/skyscale-whisper-ensure <<EOF
#!/bin/sh
exec sh "$ENSURE"
EOF
      chmod +x /usr/local/bin/skyscale-whisper-ensure 2>/dev/null || true
      (crontab -l 2>/dev/null | grep -v skyscale-whisper-ensure; echo '*/2 * * * * /usr/local/bin/skyscale-whisper-ensure >/dev/null 2>&1') | crontab - 2>/dev/null || true
    else
      # Fallback: drop into module private + optional busybox crond
      WRAP="$STT_MOD/db/private/whisper-sidecar/skyscale-whisper-ensure"
      cat > "$WRAP" <<EOF
#!/bin/sh
exec sh "$ENSURE"
EOF
      chmod +x "$WRAP" 2>/dev/null || true
      (crontab -l 2>/dev/null | grep -v skyscale-whisper-ensure; echo "*/2 * * * * $WRAP >/dev/null 2>&1") | crontab - 2>/dev/null || true
    fi
  fi

  echo "Local Whisper STT patches applied"
fi

# --- ATC Dashboard ---
DASH_DIR=
if [ -d "$BRAND_DIR/../dashboard-patches" ]; then
  DASH_DIR="$BRAND_DIR/../dashboard-patches"
elif [ -d /theme/dashboard-patches ]; then
  DASH_DIR=/theme/dashboard-patches
elif [ -d /tmp/dashboard-patches ]; then
  DASH_DIR=/tmp/dashboard-patches
fi
if [ -n "$DASH_DIR" ] && [ -d "$DASH_DIR" ]; then
  mkdir -p /usr/www/src/AdminCabinet/Controllers \
           /usr/www/src/AdminCabinet/Views/Dashboard \
           /usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard \
           /usr/www/sites/admin-cabinet/assets/css/Dashboard \
           /offload/rootfs/usr/www/src/AdminCabinet/Views/Dashboard \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/Dashboard
  [ -f "$DASH_DIR/DashboardController.php" ] && cp "$DASH_DIR/DashboardController.php" /usr/www/src/AdminCabinet/Controllers/DashboardController.php
  [ -f "$DASH_DIR/index.volt" ] && cp "$DASH_DIR/index.volt" /usr/www/src/AdminCabinet/Views/Dashboard/index.volt
  [ -f "$DASH_DIR/index.volt" ] && cp "$DASH_DIR/index.volt" /offload/rootfs/usr/www/src/AdminCabinet/Views/Dashboard/index.volt
  [ -f "$DASH_DIR/dashboard-index.js" ] && cp "$DASH_DIR/dashboard-index.js" /usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard/dashboard-index.js
  [ -f "$DASH_DIR/dashboard-index.js" ] && cp "$DASH_DIR/dashboard-index.js" /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard/dashboard-index.js
  [ -f "$DASH_DIR/dashboard.css" ] && cp "$DASH_DIR/dashboard.css" /usr/www/sites/admin-cabinet/assets/css/Dashboard/dashboard.css
  [ -f "$DASH_DIR/dashboard.css" ] && cp "$DASH_DIR/dashboard.css" /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/Dashboard/dashboard.css
  # Also inject into custom.css so styles apply even if AssetManager cache lags
  if [ -f "$DASH_DIR/dashboard.css" ] && [ -f "$CSS" ]; then
    if grep -q 'ss-dash-page-begin' "$CSS"; then
      awk '/ss-dash-page-begin/{exit} {print}' "$CSS" > /tmp/custom.css.nodash
      cp /tmp/custom.css.nodash "$CSS"
    fi
    {
      echo ''
      echo '/* ss-dash-page-begin */'
      cat "$DASH_DIR/dashboard.css"
      echo '/* ss-dash-page-end */'
    } >> "$CSS"
  fi
  find /usr/www/sites/admin-cabinet/assets/js/cache -type f \( -name '*-footer.js' -o -name '*-header.js' \) -delete 2>/dev/null || true
  echo "ATC Dashboard patched"
fi

# --- Ensure Dashboard / CallRecordings menu captions in Messages + loc JS cache ---
python3 - <<'PY'
from pathlib import Path

def ensure_msg(path: Path, key: str, value: str, after_key: str) -> None:
    if not path.exists():
        return
    t = path.read_text(encoding='utf-8')
    if f"'{key}'" in t:
        return
    needle = f"'{after_key}'"
    i = t.find(needle)
    if i < 0:
        print(f'skip {key}: no anchor {after_key} in {path}')
        return
    line_end = t.find('\n', i)
    addition = f"\n    '{key}' => '{value}',"
    path.write_text(t[:line_end] + addition + t[line_end:], encoding='utf-8')
    print(f'added {key} -> {path}')

pairs = [
    ('/usr/www/src/Common/Messages/ru/Common.php', [
        ('mm_Dashboard', 'Дашборд', 'mm_CallDetailRecords'),
        ('BreadcrumbDashboard', 'Дашборд', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderDashboard', 'Обзор телефонной системы и звонков', 'SubHeaderCallDetailRecords'),
        ('mm_CallRecordings', 'Записи звонков', 'mm_CallDetailRecords'),
        ('BreadcrumbCallRecordings', 'Записи звонков', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderCallRecordings', 'Библиотека записей разговоров', 'SubHeaderCallDetailRecords'),
        ('mm_SkyscaleStt', 'Транскрибация Whisper', 'mm_CallRecordings'),
        ('BreadcrumbSkyscaleStt', 'Транскрибация Whisper', 'BreadcrumbCallRecordings'),
        ('SubHeaderSkyscaleStt', 'Локальный Whisper / облако Miko Lab', 'SubHeaderCallRecordings'),
    ]),
    ('/usr/www/src/Common/Messages/en/Common.php', [
        ('mm_Dashboard', 'Dashboard', 'mm_CallDetailRecords'),
        ('BreadcrumbDashboard', 'Dashboard', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderDashboard', 'PBX overview and call analytics', 'SubHeaderCallDetailRecords'),
        ('mm_CallRecordings', 'Call recordings', 'mm_CallDetailRecords'),
        ('BreadcrumbCallRecordings', 'Call recordings', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderCallRecordings', 'Conversation recordings library', 'SubHeaderCallDetailRecords'),
        ('mm_SkyscaleStt', 'Whisper transcription', 'mm_CallRecordings'),
        ('BreadcrumbSkyscaleStt', 'Whisper transcription', 'BreadcrumbCallRecordings'),
        ('SubHeaderSkyscaleStt', 'Local Whisper / Miko Lab cloud', 'SubHeaderCallRecordings'),
    ]),
]
for path, items in pairs:
    p = Path(path)
    for key, value, after in items:
        ensure_msg(p, key, value, after)
    # keep offload in sync
    off = Path(path.replace('/usr/www/', '/offload/rootfs/usr/www/'))
    if p.exists() and off.parent.exists():
        off.write_text(p.read_text(encoding='utf-8'), encoding='utf-8')
        print(f'synced offload {off.name}')

# Inject into minified localization JS (menu uses globalTranslate from cache)
injections = {
    'localization-ru': {
        'keys': {
            'mm_Dashboard': 'Дашборд',
            'BreadcrumbDashboard': 'Дашборд',
            'SubHeaderDashboard': 'Обзор телефонной системы и звонков',
            'mm_CallRecordings': 'Записи звонков',
            'BreadcrumbCallRecordings': 'Записи звонков',
            'SubHeaderCallRecordings': 'Библиотека записей разговоров',
            'mm_SkyscaleStt': 'Транскрибация Whisper',
            'BreadcrumbSkyscaleStt': 'Транскрибация Whisper',
            'SubHeaderSkyscaleStt': 'Локальный Whisper / облако Miko Lab',
        },
        'anchors': [
            '"mm_CallDetailRecords":"История вызовов"',
            '"mm_CallDetailRecords":"Call Detail Records"',
            '"mm_Extensions":"Сотрудники"',
        ],
    },
    'localization-en': {
        'keys': {
            'mm_Dashboard': 'Dashboard',
            'BreadcrumbDashboard': 'Dashboard',
            'SubHeaderDashboard': 'PBX overview and call analytics',
            'mm_CallRecordings': 'Call recordings',
            'BreadcrumbCallRecordings': 'Call recordings',
            'SubHeaderCallRecordings': 'Conversation recordings library',
            'mm_SkyscaleStt': 'Whisper transcription',
            'BreadcrumbSkyscaleStt': 'Whisper transcription',
            'SubHeaderSkyscaleStt': 'Local Whisper / Miko Lab cloud',
        },
        'anchors': [
            '"mm_CallDetailRecords":"Call history"',
            '"mm_CallDetailRecords":"Call Detail Records"',
            '"mm_Extensions":"Employees"',
        ],
    },
}
cache = Path('/usr/www/sites/admin-cabinet/assets/js/cache')
if cache.exists():
    for p in cache.glob('localization-*.min.js'):
        t = p.read_text(encoding='utf-8', errors='ignore')
        for prefix, cfg in injections.items():
            if not p.name.startswith(prefix):
                continue
            missing = {k: v for k, v in cfg['keys'].items() if f'"{k}"' not in t}
            if not missing:
                print(f'loc ok {p.name}')
                continue
            add = ''.join(f',"{k}":"{v}"' for k, v in missing.items())
            placed = False
            for a in cfg['anchors']:
                if a in t:
                    t = t.replace(a, a + add, 1)
                    p.write_text(t, encoding='utf-8')
                    print(f'loc injected missing keys into {p.name}: {list(missing)}')
                    placed = True
                    break
            if not placed:
                # fallback: append after first mm_ key occurrence
                for k in ('"mm_CallRecordings"', '"mm_Dashboard"', '"mm_Extensions"'):
                    if k in t:
                        idx = t.find(k)
                        q1 = t.find('"', t.find(':', idx) + 1)
                        q2 = t.find('"', q1 + 1)
                        if q2 > 0:
                            t = t[:q2+1] + add + t[q2+1:]
                            p.write_text(t, encoding='utf-8')
                            print(f'loc injected via fallback {k} into {p.name}')
                            placed = True
                            break
            if not placed:
                print(f'loc anchor missing {p.name}')
print('localization keys ensured')
PY

# Bust MessagesProvider ManagedCache so new mm_* keys appear in sidebar
if [ -f "$BRAND_DIR/../clear-localisation-cache.sh" ]; then
  sh "$BRAND_DIR/../clear-localisation-cache.sh" || true
elif [ -f /tmp/clear-localisation-cache.sh ]; then
  sh /tmp/clear-localisation-cache.sh || true
else
  php -r '
try {
  $redis = new Redis();
  if (@$redis->connect("127.0.0.1", 6379, 1.5)) {
    foreach ($redis->keys("*Localisation*") as $k) { $redis->del($k); }
    echo "localisation redis cleared\n";
  }
} catch (Throwable $e) { echo $e->getMessage(),"\n"; }
' || true
fi

# --- Default home page after login → Dashboard ---
python3 - <<'PY'
from pathlib import Path

replacements = [
    (
        Path('/usr/www/src/Common/Library/Auth/CredentialsValidator.php'),
        "/admin-cabinet/extensions/index",
        "/admin-cabinet/dashboard/index",
    ),
    (
        Path('/usr/www/src/PBXCoreREST/Lib/Auth/RefreshAction.php'),
        "/admin-cabinet/extensions/index",
        "/admin-cabinet/dashboard/index",
    ),
    (
        Path('/usr/www/src/AdminCabinet/Plugins/SecurityPlugin.php'),
        "/admin-cabinet/extensions/index",
        "/admin-cabinet/dashboard/index",
    ),
    (
        Path('/usr/www/src/AdminCabinet/Plugins/SecurityPlugin.php'),
        "extensions/index",
        "dashboard/index",
    ),
]

for path, old, new in replacements:
    if not path.exists():
        print(f'skip missing {path}')
        continue
    t = path.read_text(encoding='utf-8')
    if old not in t:
        print(f'ok already {path.name}: no {old!r}')
        continue
    path.write_text(t.replace(old, new), encoding='utf-8')
    print(f'patched {path}: {old} -> {new}')

# login-form.js fallback (src + pbx + minified cache may lag)
login_candidates = [
    Path('/usr/www/sites/admin-cabinet/assets/js/pbx/Session/login-form.js'),
    Path('/usr/www/sites/admin-cabinet/assets/js/src/Session/login-form.js'),
]
for path in login_candidates:
    if not path.exists():
        continue
    t = path.read_text(encoding='utf-8')
    nt = t.replace('extensions/index', 'dashboard/index')
    if nt != t:
        path.write_text(nt, encoding='utf-8')
        print(f'patched {path}')
    else:
        print(f'ok {path.name}')

# Also patch any cached footer/header that still embeds old fallback
cache = Path('/usr/www/sites/admin-cabinet/assets/js/cache')
if cache.exists():
    for p in cache.glob('*-footer.js'):
        t = p.read_text(encoding='utf-8', errors='ignore')
        if 'extensions/index' in t and 'homePage' in t:
            p.write_text(t.replace('extensions/index', 'dashboard/index'), encoding='utf-8')
            print(f'patched cache {p.name}')
print('home page -> dashboard done')
PY

rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true

# Silence broken cdr_beanstalkd load (Miko history uses CEL → asterisk-cel, not CDR tube)
CDR_BS_CONF=/etc/asterisk/cdr_beanstalkd.conf
CDR_BS_SRC=
if [ -f "$BRAND_DIR/../cdr_beanstalkd.conf" ]; then
  CDR_BS_SRC="$BRAND_DIR/../cdr_beanstalkd.conf"
elif [ -f /tmp/cdr_beanstalkd.conf ]; then
  CDR_BS_SRC=/tmp/cdr_beanstalkd.conf
elif [ -f /theme/cdr_beanstalkd.conf ]; then
  CDR_BS_SRC=/theme/cdr_beanstalkd.conf
fi
if [ -n "$CDR_BS_SRC" ]; then
  cp "$CDR_BS_SRC" "$CDR_BS_CONF"
  asterisk -rx 'module reload cdr_beanstalkd.so' >/dev/null 2>&1 || \
    asterisk -rx 'module load cdr_beanstalkd.so' >/dev/null 2>&1 || true
  echo "cdr_beanstalkd.conf installed (disabled; CEL path is used for history)"
fi
