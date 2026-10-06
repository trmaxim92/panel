#!/bin/sh
# Host wrapper: copy + run cleanup inside mikopbx, install daily cron.
set -eu
C="${MIKO_CONTAINER:-mikopbx}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
INNER="$SCRIPT_DIR/cleanup-disk-inner.sh"
KEEP_ROTATED="${KEEP_ROTATED:-2}"
MAX_ACTIVE_MB="${MAX_ACTIVE_MB:-200}"

echo "== before =="
df -h / | tail -1
docker exec "$C" sh -c 'du -sh /storage/usbdisk1/mikopbx/log /storage/usbdisk1/mikopbx/log/asterisk /root/.cache 2>/dev/null || true'

docker cp "$INNER" "$C:/tmp/cleanup-disk-inner.sh"
docker exec -e KEEP_ROTATED="$KEEP_ROTATED" -e MAX_ACTIVE_MB="$MAX_ACTIVE_MB" \
  "$C" sh /tmp/cleanup-disk-inner.sh

echo "== after host =="
df -h / | tail -1
echo DONE
