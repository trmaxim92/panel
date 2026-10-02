#!/usr/bin/env bash
# Deploy overlay/ + theme onto running mikopbx container (VPS).
# Usage: sudo bash deploy-overlay.sh
# Mirrors local .\dev-apply-overlay.ps1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OVERLAY="$ROOT/overlay/usr/www"
THEME="$ROOT/theme"
CONTAINER="${MIKO_CONTAINER:-mikopbx}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Container $CONTAINER is not running" >&2
  exit 1
fi

echo "== copy overlay into container =="
docker cp "$OVERLAY/." "$CONTAINER:/usr/www/"
docker exec "$CONTAINER" sh -c 'mkdir -p /offload/rootfs/usr/www && cp -a /usr/www/src /offload/rootfs/usr/www/ 2>/dev/null || true'
docker exec "$CONTAINER" sh -c 'mkdir -p /offload/rootfs/usr/www/sites/admin-cabinet/assets && cp -a /usr/www/sites/admin-cabinet/assets/css /usr/www/sites/admin-cabinet/assets/js /offload/rootfs/usr/www/sites/admin-cabinet/assets/ 2>/dev/null || true'

echo "== apply theme + CDR/Dashboard/Recordings patches =="
# Fresh /tmp patch dirs — avoid nested docker cp leftovers
docker exec "$CONTAINER" sh -c 'rm -rf /tmp/cdr-patches /tmp/layout-patches /tmp/extensions-patches /tmp/dashboard-patches /tmp/monitor-patches /tmp/stt-patches /tmp/brand /tmp/apply-in-container.sh /tmp/skyscale-theme.css /tmp/clear-localisation-cache.sh'

docker cp "$THEME/skyscale-theme.css" "$CONTAINER:/tmp/skyscale-theme.css"
docker cp "$THEME/apply-in-container.sh" "$CONTAINER:/tmp/apply-in-container.sh"
docker cp "$THEME/clear-localisation-cache.sh" "$CONTAINER:/tmp/clear-localisation-cache.sh" 2>/dev/null || true
docker cp "$THEME/cdr-patches" "$CONTAINER:/tmp/cdr-patches"
docker cp "$THEME/layout-patches" "$CONTAINER:/tmp/layout-patches"
docker cp "$THEME/extensions-patches" "$CONTAINER:/tmp/extensions-patches"
docker cp "$THEME/dashboard-patches" "$CONTAINER:/tmp/dashboard-patches"
if [ -d "$THEME/monitor-patches" ]; then
  docker cp "$THEME/monitor-patches" "$CONTAINER:/tmp/monitor-patches"
fi
if [ -d "$THEME/stt-patches" ]; then
  docker cp "$THEME/stt-patches" "$CONTAINER:/tmp/stt-patches"
fi
if [ -d "$THEME/brand" ]; then
  docker exec "$CONTAINER" mkdir -p /tmp/brand
  tar -C "$THEME/brand" -cf - . | docker exec -i "$CONTAINER" tar -C /tmp/brand -xf -
fi

docker exec "$CONTAINER" sh -c \
  'THEME_SRC=/tmp/skyscale-theme.css BRAND_DIR=/tmp/brand CDR_PATCH_DIR=/tmp/cdr-patches sh /tmp/apply-in-container.sh'

# Force-copy dashboard assets (guard against nested /tmp leftovers)
if [ -f "$THEME/dashboard-patches/dashboard-index.js" ]; then
  docker cp "$THEME/dashboard-patches/dashboard-index.js" "$CONTAINER:/usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard/dashboard-index.js"
  docker cp "$THEME/dashboard-patches/dashboard-index.js" "$CONTAINER:/offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/Dashboard/dashboard-index.js"
fi
if [ -f "$THEME/dashboard-patches/index.volt" ]; then
  docker cp "$THEME/dashboard-patches/index.volt" "$CONTAINER:/usr/www/src/AdminCabinet/Views/Dashboard/index.volt"
  docker cp "$THEME/dashboard-patches/index.volt" "$CONTAINER:/offload/rootfs/usr/www/src/AdminCabinet/Views/Dashboard/index.volt"
fi
if [ -f "$THEME/dashboard-patches/dashboard.css" ]; then
  docker cp "$THEME/dashboard-patches/dashboard.css" "$CONTAINER:/usr/www/sites/admin-cabinet/assets/css/Dashboard/dashboard.css"
  docker cp "$THEME/dashboard-patches/dashboard.css" "$CONTAINER:/offload/rootfs/usr/www/sites/admin-cabinet/assets/css/Dashboard/dashboard.css"
fi

# Always clear localisation (ManagedCache lives in Redis db != 0)
if [ -f "$THEME/clear-localisation-cache.sh" ]; then
  docker cp "$THEME/clear-localisation-cache.sh" "$CONTAINER:/tmp/clear-localisation-cache.sh"
  docker exec "$CONTAINER" sh /tmp/clear-localisation-cache.sh || true
fi

docker exec "$CONTAINER" sh -c 'php -r "if(function_exists(\"opcache_reset\")) opcache_reset();" 2>/dev/null || true'
docker exec "$CONTAINER" sh -c 'rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true'
docker exec "$CONTAINER" sh -c 'find /usr/www/sites/admin-cabinet/assets/js/cache -type f \( -name "*-footer.js" -o -name "*-header.js" \) -delete 2>/dev/null || true'

echo "== restart WorkerApiCommands (CDR API PHP) =="
if [ -f "$ROOT/theme/restart-api-workers.sh" ]; then
  docker cp "$ROOT/theme/restart-api-workers.sh" "$CONTAINER:/tmp/_fix_workers2.sh"
  docker exec "$CONTAINER" sh /tmp/_fix_workers2.sh || true
else
  docker exec "$CONTAINER" sh -c 'pkill -f WorkerApiCommands || true; sleep 1; /usr/bin/php -f /usr/www/src/Core/Workers/WorkerApiCommands.php >/dev/null 2>&1 &' || true
fi

echo "OK: overlay deployed to $CONTAINER. Hard-refresh admin UI (Ctrl+F5)."
