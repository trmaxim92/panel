#!/bin/sh
set -e
IMG=/offload/rootfs/usr/www/sites/admin-cabinet/assets/img
CTRL=/usr/www/src/AdminCabinet/Controllers/BaseController.php

cp /tmp/logo-skayskel.png "$IMG/logo-mikopbx.png"
cp /tmp/logo-skayskel.png "$IMG/logo.png"
cp "$CTRL" "${CTRL}.bak-logo" 2>/dev/null || true
sed -i 's|assets/img/logo-mikopbx.svg|assets/img/logo-mikopbx.png|g' "$CTRL"
grep urlToLogo "$CTRL"
ls -la "$IMG/logo-mikopbx.png"
