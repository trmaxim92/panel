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
  for f in leftsidebar.volt topMenu.volt mainHeader.volt emptyTablePlaceholder.volt tablesbuttons.volt; do
    if [ -f "$LAYOUT_DIR/$f" ]; then
      cp "$LAYOUT_DIR/$f" "$PARTIALS/$f"
      cp "$LAYOUT_DIR/$f" "$OFF_PARTIALS/$f" 2>/dev/null || true
    fi
  done
  echo "Layout partials patched"
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
  mkdir -p /usr/www/src/AdminCabinet/Views/CallRecordings \
           /usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings \
           /usr/www/sites/admin-cabinet/assets/css/CallRecordings \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings \
           /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/CallRecordings
  [ -f "$CR/index.volt" ] && cp "$CR/index.volt" /usr/www/src/AdminCabinet/Views/CallRecordings/index.volt
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
    ]),
    ('/usr/www/src/Common/Messages/en/Common.php', [
        ('mm_Dashboard', 'Dashboard', 'mm_CallDetailRecords'),
        ('BreadcrumbDashboard', 'Dashboard', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderDashboard', 'PBX overview and call analytics', 'SubHeaderCallDetailRecords'),
        ('mm_CallRecordings', 'Call recordings', 'mm_CallDetailRecords'),
        ('BreadcrumbCallRecordings', 'Call recordings', 'BreadcrumbCallDetailRecords'),
        ('SubHeaderCallRecordings', 'Conversation recordings library', 'SubHeaderCallDetailRecords'),
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
        'anchor': '"mm_CallDetailRecords":"История вызовов"',
        'add': ',"mm_Dashboard":"Дашборд","BreadcrumbDashboard":"Дашборд","SubHeaderDashboard":"Обзор телефонной системы и звонков","mm_CallRecordings":"Записи звонков","BreadcrumbCallRecordings":"Записи звонков","SubHeaderCallRecordings":"Библиотека записей разговоров"',
        'need': 'mm_Dashboard',
    },
    'localization-en': {
        'anchor': '"mm_CallDetailRecords":"Call history"',
        'add': ',"mm_Dashboard":"Dashboard","BreadcrumbDashboard":"Dashboard","SubHeaderDashboard":"PBX overview and call analytics","mm_CallRecordings":"Call recordings","BreadcrumbCallRecordings":"Call recordings","SubHeaderCallRecordings":"Conversation recordings library"',
        'need': 'mm_Dashboard',
    },
}
cache = Path('/usr/www/sites/admin-cabinet/assets/js/cache')
if cache.exists():
    for p in cache.glob('localization-*.min.js'):
        t = p.read_text(encoding='utf-8', errors='ignore')
        for prefix, cfg in injections.items():
            if not p.name.startswith(prefix):
                continue
            if cfg['need'] in t:
                print(f'loc ok {p.name}')
                continue
            if cfg['anchor'] not in t:
                # try alternate anchors
                alts = [
                    '"mm_CallDetailRecords":"Call Detail Records"',
                    '"mm_Extensions":"Сотрудники"',
                    '"mm_Extensions":"Employees"',
                ]
                done = False
                for a in alts:
                    if a in t:
                        p.write_text(t.replace(a, a + cfg['add'], 1), encoding='utf-8')
                        print(f'loc injected via alt into {p.name}')
                        done = True
                        break
                if not done:
                    print(f'loc anchor missing {p.name}')
                continue
            p.write_text(t.replace(cfg['anchor'], cfg['anchor'] + cfg['add'], 1), encoding='utf-8')
            print(f'loc injected {p.name}')
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
