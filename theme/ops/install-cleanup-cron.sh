#!/bin/sh
# Install host cron for daily SkyScale disk cleanup + logger tune.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO="${REPO:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}"
CRON_FILE=/etc/cron.d/skyscale-disk-cleanup

mkdir -p "$REPO/theme/ops" /var/log/skyscale
cat > "$CRON_FILE" <<EOF
# SkyScale — prune Asterisk log rotations and caches (daily 03:25)
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
25 3 * * * root KEEP_ROTATED=1 MAX_ACTIVE_MB=100 $REPO/theme/ops/cleanup-disk.sh >> /var/log/skyscale/cleanup-disk.log 2>&1
40 3 * * * root $REPO/theme/ops/tune-asterisk-logger.sh >> /var/log/skyscale/cleanup-disk.log 2>&1
EOF
chmod 644 "$CRON_FILE"
chmod +x "$REPO/theme/ops/cleanup-disk.sh" "$REPO/theme/ops/cleanup-disk-inner.sh" "$REPO/theme/ops/tune-asterisk-logger.sh" 2>/dev/null || true

# Also drop another rotation now (keep only .0)
KEEP_ROTATED=1 MAX_ACTIVE_MB=100 "$REPO/theme/ops/cleanup-disk.sh"

echo "cron installed: $CRON_FILE"
ls -la "$CRON_FILE"
