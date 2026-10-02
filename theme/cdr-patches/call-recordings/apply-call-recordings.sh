#!/bin/sh
# Install Call Recordings page into running MikoPBX container
set -e
SRC=${SRC_DIR:-/tmp/call-recordings}

CTRL_DST=/usr/www/src/AdminCabinet/Controllers/CallRecordingsController.php
VIEW_DIR=/usr/www/src/AdminCabinet/Views/CallRecordings
JS_DIR=/usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings
CSS_DIR=/usr/www/sites/admin-cabinet/assets/css/CallRecordings
OFF_JS=/offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings
OFF_CSS=/offload/rootfs/usr/www/sites/admin-cabinet/assets/css/CallRecordings
CSS_CUSTOM=/offload/rootfs/usr/www/sites/admin-cabinet/assets/css/custom.css
ELEMENTS=/usr/www/src/AdminCabinet/Library/Elements.php
ASSETS=/usr/www/src/AdminCabinet/Providers/AssetProvider.php
MSG_RU=/usr/www/src/Common/Messages/ru/Common.php
MSG_EN=/usr/www/src/Common/Messages/en/Common.php

mkdir -p "$VIEW_DIR" "$JS_DIR" "$CSS_DIR" "$OFF_JS" "$OFF_CSS"

cp "$SRC/CallRecordingsController.php" "$CTRL_DST"
cp "$SRC/index.volt" "$VIEW_DIR/index.volt"
cp "$SRC/call-recordings-index.js" "$JS_DIR/call-recordings-index.js"
cp "$SRC/call-recordings-index.js" "$OFF_JS/call-recordings-index.js"
cp "$SRC/call-recordings.css" "$CSS_DIR/call-recordings.css"
cp "$SRC/call-recordings.css" "$OFF_CSS/call-recordings.css"

# --- Menu ---
python3 - <<'PY'
from pathlib import Path
p = Path("/usr/www/src/AdminCabinet/Library/Elements.php")
t = p.read_text()
changed = False
use_line = "use MikoPBX\\AdminCabinet\\Controllers\\CallRecordingsController;"
if use_line not in t:
    t = t.replace(
        "use MikoPBX\\AdminCabinet\\Controllers\\CallDetailRecordsController;",
        "use MikoPBX\\AdminCabinet\\Controllers\\CallDetailRecordsController;\n" + use_line,
    )
    changed = True

if "CallRecordingsController::class" not in t:
    cdr = """                    CallDetailRecordsController::class => [
                        'caption' => 'mm_CallDetailRecords',
                        'iconclass' => 'list ul',
                        'action' => 'index',
                        'param' => '#reset-cache',
                        'style' => '',
                    ],"""
    insert = cdr + """
                    CallRecordingsController::class => [
                        'caption' => 'mm_CallRecordings',
                        'iconclass' => 'file audio outline',
                        'action' => 'index',
                        'param' => '',
                        'style' => '',
                    ],"""
    if cdr not in t:
        raise SystemExit("CDR menu block not found for insert")
    t = t.replace(cdr, insert, 1)
    changed = True

if changed:
    p.write_text(t)
    print("Elements.php updated")
else:
    print("Elements.php already OK")
PY

# --- Messages ---
python3 - <<'PY'
from pathlib import Path

def add_msg(path, key, value, after_key):
    p = Path(path)
    if not p.exists():
        return
    t = p.read_text(encoding='utf-8')
    if f"'{key}'" in t:
        return
    needle = f"'{after_key}'"
    i = t.find(needle)
    if i < 0:
        print(f"skip {key}: anchor {after_key} missing in {path}")
        return
    # find end of that line's array entry
    line_end = t.find("\n", i)
    entry = t[i:line_end]
    # keep trailing comma style
    if entry.rstrip().endswith(','):
        addition = f"\n    '{key}' => '{value}',"
    else:
        # add comma to previous then new line
        t = t[:line_end] + ',' + t[line_end:]
        line_end = t.find("\n", i)
        addition = f"\n    '{key}' => '{value}',"
    t = t[:line_end] + addition + t[line_end:]
    p.write_text(t, encoding='utf-8')
    print(f"added {key} to {path}")

add_msg("/usr/www/src/Common/Messages/ru/Common.php", "mm_CallRecordings", "Записи звонков", "mm_CallDetailRecords")
add_msg("/usr/www/src/Common/Messages/ru/Common.php", "BreadcrumbCallRecordings", "Записи звонков", "BreadcrumbCallDetailRecords")
add_msg("/usr/www/src/Common/Messages/ru/Common.php", "SubHeaderCallRecordings", "Библиотека записей разговоров", "SubHeaderCallDetailRecords")
add_msg("/usr/www/src/Common/Messages/en/Common.php", "mm_CallRecordings", "Call recordings", "mm_CallDetailRecords")
add_msg("/usr/www/src/Common/Messages/en/Common.php", "BreadcrumbCallRecordings", "Call recordings", "BreadcrumbCallDetailRecords")
add_msg("/usr/www/src/Common/Messages/en/Common.php", "SubHeaderCallRecordings", "Conversation recordings library", "SubHeaderCallDetailRecords")
PY

# --- AssetProvider method (auto-dispatched as make{Controller}Assets) ---
python3 - <<'PY'
from pathlib import Path
p = Path("/usr/www/src/AdminCabinet/Providers/AssetProvider.php")
t = p.read_text()
if "makeCallRecordingsAssets" in t:
    print("AssetProvider already has makeCallRecordingsAssets")
else:
    method = '''
    /**
     * Makes assets for the CallRecordings controller (SkyScale)
     *
     * @param string $action
     */
    private function makeCallRecordingsAssets(string $action): void
    {
        if ($action === 'index') {
            $this->semanticCollectionCSS
                ->addCss('css/vendor/semantic/search.min.css', true)
                ->addCss('css/vendor/datepicker/daterangepicker.css', true)
                ->addCss('css/vendor/datatable/dataTables.semanticui.min.css', true)
                ->addCss('css/CallRecordings/call-recordings.css', true);

            $this->semanticCollectionJS
                ->addJs('js/vendor/semantic/search.min.js', true)
                ->addJs('js/vendor/datatable/dataTables.semanticui.js', true)
                ->addJS('js/vendor/moment/moment.min.js', true)
                ->addJS('js/vendor/datepicker/daterangepicker.js', true);

            $this->footerCollectionJS
                ->addJs('js/pbx/PbxAPI/cdr-api.js', true)
                ->addJs('js/pbx/CallRecordings/call-recordings-index.js', true);
        }
    }

'''
    anchor = "    private function makeCallDetailRecordsAssets(string $action): void"
    idx = t.find(anchor)
    if idx < 0:
        raise SystemExit("makeCallDetailRecordsAssets not found")
    t = t[:idx] + method + t[idx:]
    p.write_text(t)
    print("AssetProvider: makeCallRecordingsAssets added")
PY

# --- custom.css ---
if [ -f "$CSS_CUSTOM" ]; then
  if grep -q 'ss-rec-page-begin' "$CSS_CUSTOM"; then
    awk '/ss-rec-page-begin/{exit} {print}' "$CSS_CUSTOM" > /tmp/custom.css.norec
    cp /tmp/custom.css.norec "$CSS_CUSTOM"
  fi
  {
    echo ''
    echo '/* ss-rec-page-begin */'
    echo '#rec-filters-panel.ss-cdr-panel { background:#fff; border:1px solid #e6e8ef; border-radius:14px; padding:16px 18px 12px; margin-bottom:16px; box-shadow:0 1px 2px rgba(26,29,39,.04); overflow:visible; position:relative; z-index:5; }'
    cat "$SRC/call-recordings.css"
    cat "$SRC/cdr-filters-mirror.css"
    echo '/* ss-rec-page-end */'
  } >> "$CSS_CUSTOM"
fi

rm -rf /storage/usbdisk1/mikopbx/tmp/volt 2>/dev/null || true
find /usr/www/sites/admin-cabinet/assets/js/cache -type f \( -name '*-footer.js' -o -name '*-header.js' \) -delete 2>/dev/null || true
php -r 'if(function_exists("opcache_reset")){opcache_reset(); echo "opcache_reset\n";}'

# Ensure menu captions exist in localization JS (cache may lag MessagesProvider)
python3 - <<'PY'
from pathlib import Path
files = list(Path('/usr/www/sites/admin-cabinet/assets/js/cache').glob('localization-ru-*.min.js'))
for p in files:
    t = p.read_text(encoding='utf-8')
    if 'mm_CallRecordings' in t:
        print('loc ok', p.name)
        continue
    old = '"mm_CallDetailRecords":"История вызовов"'
    if old not in t:
        print('loc anchor missing', p.name)
        continue
    new = old + ',"mm_CallRecordings":"Записи звонков","BreadcrumbCallRecordings":"Записи звонков","SubHeaderCallRecordings":"Библиотека записей разговоров"'
    p.write_text(t.replace(old, new, 1), encoding='utf-8')
    print('loc injected', p.name)
PY

# Keep offload messages in sync
OFF_MSG=/offload/rootfs/usr/www/src/Common/Messages/ru/Common.php
if [ -f "$OFF_MSG" ] && ! grep -q "mm_CallRecordings" "$OFF_MSG"; then
  cp "$MSG_RU" "$OFF_MSG"
fi

echo "== verify =="
ls -la "$CTRL_DST" "$VIEW_DIR/index.volt" "$JS_DIR/call-recordings-index.js"
grep -n 'CallRecordings' "$ELEMENTS" | head -12
grep -n 'makeCallRecordingsAssets' "$ASSETS" | head -5
grep -n 'mm_CallRecordings\|BreadcrumbCallRecordings\|SubHeaderCallRecordings' "$MSG_RU" | head -10
php -l "$CTRL_DST"
echo OK
