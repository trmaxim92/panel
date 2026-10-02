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
docker cp "$THEME/skyscale-theme.css" "$CONTAINER:/tmp/skyscale-theme.css"
docker cp "$THEME/apply-in-container.sh" "$CONTAINER:/tmp/apply-in-container.sh"
docker cp "$THEME/clear-localisation-cache.sh" "$CONTAINER:/tmp/clear-localisation-cache.sh" 2>/dev/null || true
docker cp "$THEME/cdr-patches" "$CONTAINER:/tmp/cdr-patches"
docker cp "$THEME/layout-patches" "$CONTAINER:/tmp/layout-patches"
docker cp "$THEME/extensions-patches" "$CONTAINER:/tmp/extensions-patches"
docker cp "$THEME/dashboard-patches" "$CONTAINER:/tmp/dashboard-patches"
if [ -d "$THEME/brand" ]; then
  docker exec "$CONTAINER" mkdir -p /tmp/brand
  tar -C "$THEME/brand" -cf - . | docker exec -i "$CONTAINER" tar -C /tmp/brand -xf -
fi

docker exec "$CONTAINER" sh -c \
  'THEME_SRC=/tmp/skyscale-theme.css BRAND_DIR=/tmp/brand CDR_PATCH_DIR=/tmp/cdr-patches sh /tmp/apply-in-container.sh'

docker exec "$CONTAINER" sh -c 'php -r "if(function_exists(\"opcache_reset\")) opcache_reset();" 2>/dev/null || true'
docker exec "$CONTAINER" sh -c 'rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true'

echo "== restart WorkerApiCommands (CDR API PHP) =="
if [ -f "$ROOT/theme/restart-api-workers.sh" ]; then
  docker cp "$ROOT/theme/restart-api-workers.sh" "$CONTAINER:/tmp/_fix_workers2.sh"
  docker exec "$CONTAINER" sh /tmp/_fix_workers2.sh || true
else
  docker exec "$CONTAINER" sh -c 'pkill -f WorkerApiCommands || true; sleep 1; /usr/bin/php -f /usr/www/src/Core/Workers/WorkerApiCommands.php >/dev/null 2>&1 &' || true
fi

echo "OK: overlay deployed to $CONTAINER. Hard-refresh admin UI (Ctrl+F5)."
