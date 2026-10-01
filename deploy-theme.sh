#!/usr/bin/env bash
# Apply theme+logo to running mikopbx container on VPS (after git pull)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONTAINER="${MIKO_CONTAINER:-mikopbx}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Container '$CONTAINER' is not running" >&2
  exit 1
fi

docker cp "$ROOT/theme/skyscale-theme.css" "$CONTAINER:/tmp/skyscale-theme.css"
docker cp "$ROOT/theme/apply-in-container.sh" "$CONTAINER:/tmp/apply-in-container.sh"
docker cp -r "$ROOT/theme/brand" "$CONTAINER:/tmp/brand"

docker exec "$CONTAINER" sh -c \
  'THEME_SRC=/tmp/skyscale-theme.css BRAND_DIR=/tmp/brand sh /tmp/apply-in-container.sh'

echo "OK — open PBX UI and hard-refresh (Ctrl+F5)"
