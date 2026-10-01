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
elif [ -f /tmp/logo-skayskel.png ]; then
  cp /tmp/logo-skayskel.png "$IMGDIR/logo-skayskel.png"
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

if grep -q 'ss-theme-begin\|SkyScale theme\|ss-hover-fix' "$CSS"; then
  awk '/ss-theme-begin|\/\* SkyScale|\/\* ss-hover-fix/{exit} {print}' "$CSS" > /tmp/custom.css.base
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
