#!/bin/sh
# Deploy Skyscale STT page fix into running container
set -e
SRC=${1:-/tmp/stt-patches}

cp -f "$SRC/SkyscaleSttController.php" /usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php
cp -f "$SRC/SkyscaleSttController.php" /offload/rootfs/usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php 2>/dev/null || true
mkdir -p /usr/www/src/AdminCabinet/Views/SkyscaleStt /offload/rootfs/usr/www/src/AdminCabinet/Views/SkyscaleStt
cp -f "$SRC/views/index.volt" /usr/www/src/AdminCabinet/Views/SkyscaleStt/index.volt
cp -f "$SRC/views/index.volt" /offload/rootfs/usr/www/src/AdminCabinet/Views/SkyscaleStt/index.volt 2>/dev/null || true
mkdir -p /usr/www/sites/admin-cabinet/assets/css/SkyscaleStt
cp -f "$SRC/skyscale-stt.css" /usr/www/sites/admin-cabinet/assets/css/SkyscaleStt/skyscale-stt.css

# Ensure Messages keys
python3 - <<'PY'
from pathlib import Path
pairs = [
    (Path('/usr/www/src/Common/Messages/ru/Common.php'), {
        'mm_SkyscaleStt': 'Транскрибация Whisper',
        'BreadcrumbSkyscaleStt': 'Транскрибация Whisper',
        'SubHeaderSkyscaleStt': 'Локальный Whisper / облако Miko Lab',
    }),
    (Path('/usr/www/src/Common/Messages/en/Common.php'), {
        'mm_SkyscaleStt': 'Whisper transcription',
        'BreadcrumbSkyscaleStt': 'Whisper transcription',
        'SubHeaderSkyscaleStt': 'Local Whisper / Miko Lab cloud',
    }),
]
for path, keys in pairs:
    t = path.read_text(encoding='utf-8')
    changed = False
    for k, v in keys.items():
        if f"'{k}'" not in t:
            # insert after mm_CallRecordings if present
            anchor = "'mm_CallRecordings'"
            i = t.find(anchor)
            if i < 0:
                continue
            line_end = t.find('\n', i)
            t = t[:line_end] + f"\n    '{k}' => '{v}'," + t[line_end:]
            changed = True
            print(f'added {k} -> {path}')
    if changed:
        path.write_text(t, encoding='utf-8')
        off = Path(str(path).replace('/usr/www/', '/offload/rootfs/usr/www/'))
        if off.parent.exists():
            off.write_text(t, encoding='utf-8')
PY

# Force inject into localization JS even if mm_Dashboard already present
python3 - <<'PY'
from pathlib import Path
cache = Path('/usr/www/sites/admin-cabinet/assets/js/cache')
injections = {
    'localization-ru': ',"mm_SkyscaleStt":"Транскрибация Whisper","BreadcrumbSkyscaleStt":"Транскрибация Whisper","SubHeaderSkyscaleStt":"Локальный Whisper / облако Miko Lab"',
    'localization-en': ',"mm_SkyscaleStt":"Whisper transcription","BreadcrumbSkyscaleStt":"Whisper transcription","SubHeaderSkyscaleStt":"Local Whisper / Miko Lab cloud"',
}
for p in cache.glob('localization-*.min.js'):
    t = p.read_text(encoding='utf-8', errors='ignore')
    for prefix, add in injections.items():
        if not p.name.startswith(prefix):
            continue
        if 'mm_SkyscaleStt' in t:
            print(f'loc already has key {p.name}')
            continue
        # append near mm_CallRecordings or mm_Dashboard
        for anchor in ('"mm_CallRecordings"', '"mm_Dashboard"', '"mm_CallDetailRecords"'):
            if anchor in t:
                # find end of that key's value string roughly — insert after the whole "k":"v"
                idx = t.find(anchor)
                # find closing quote of value
                colon = t.find(':', idx)
                if colon < 0:
                    continue
                # value starts at next quote
                q1 = t.find('"', colon)
                q2 = t.find('"', q1 + 1)
                if q2 < 0:
                    continue
                t = t[:q2+1] + add + t[q2+1:]
                p.write_text(t, encoding='utf-8')
                print(f'loc injected {p.name} via {anchor}')
                break
PY

# Clear caches
php -r 'if(function_exists("opcache_reset")){opcache_reset(); echo "opcache_reset\n";}'
rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true
php -r '
try {
  $redis = new Redis();
  if (@$redis->connect("127.0.0.1", 6379, 1.5)) {
    foreach ($redis->keys("*Localisation*") as $k) { $redis->del($k); }
    foreach ($redis->keys("*Acl*") as $k) { $redis->del($k); }
    foreach ($redis->keys("*ACL*") as $k) { $redis->del($k); }
    echo "redis caches cleared\n";
  }
} catch (Throwable $e) { echo $e->getMessage(),"\n"; }
' || true

php -l /usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php
wc -c /usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php
grep -c SkyscaleProviderConfig /usr/www/src/AdminCabinet/Controllers/SkyscaleSttController.php || echo 'no module dependency'
grep -c mm_SkyscaleStt /usr/www/sites/admin-cabinet/assets/js/cache/localization-ru*.min.js || echo 'loc still missing'
echo DONE
