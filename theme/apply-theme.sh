#!/bin/sh
set -e
CSSDIR=/offload/rootfs/usr/www/sites/admin-cabinet/assets/css
FONTDIR=/offload/rootfs/usr/www/sites/admin-cabinet/assets/fonts
CSS=$CSSDIR/custom.css
THEME=$CSSDIR/skyscale-theme.css

mkdir -p "$FONTDIR"

# Local Manrope (CSP blocks fonts.googleapis.com)
if [ ! -f "$FONTDIR/manrope-latin.woff2" ]; then
  wget -q -O "$FONTDIR/manrope-latin.woff2" \
    "https://fonts.gstatic.com/s/manrope/v20/xn7_YHE7xsMPPfBylUsDX8tTNw.woff2" || true
fi

# Rebuild theme without remote @import
cat > "$THEME" <<'EOF'
/* СкайСкейл — тема MikoPBX (цвета + шрифты), CSP-safe */

@font-face {
  font-family: 'Manrope';
  font-style: normal;
  font-weight: 400 800;
  font-display: swap;
  src: url('../fonts/manrope-latin.woff2') format('woff2');
}

:root {
  --ss-sidebar: #1e212b;
  --ss-sidebar-hover: #2a2e3b;
  --ss-accent: #9c2732;
  --ss-accent-hover: #b52f3c;
  --ss-accent-soft: #fdecee;
  --ss-surface: #f3f4f7;
  --ss-text: #1a1d27;
  --ss-muted: #8b90a0;
}

html, body, .ui, button, input, select, textarea,
.ui.button, .ui.menu, .ui.header, .ui.table, .ui.label,
.ui.form input, .ui.form textarea, .ui.dropdown {
  font-family: 'Manrope', 'Segoe UI', Tahoma, sans-serif !important;
}

body {
  background: var(--ss-surface) !important;
  color: var(--ss-text);
}

/* Sidebar + top bar (dark shell) */
#sidebarnav,
#sidebar-menu,
.sidebar-menu,
.ui.inverted.menu,
.ui.vertical.inverted.menu,
.ui.left.fixed.menu,
.ui.top.fixed.inverted.menu,
.ui.menu.inverted {
  background: var(--ss-sidebar) !important;
}

.ui.inverted.menu .item,
.ui.vertical.inverted.menu .item {
  color: #d7dae5 !important;
  font-weight: 600 !important;
}

.ui.inverted.menu .item:hover,
.ui.vertical.inverted.menu .item:hover {
  background: var(--ss-sidebar-hover) !important;
  color: #fff !important;
}

.ui.inverted.menu .active.item,
.ui.vertical.inverted.menu .active.item {
  background: var(--ss-accent) !important;
  color: #fff !important;
}

/* Primary / blue buttons → бордовый */
.ui.primary.button,
.ui.primary.buttons .button,
.ui.blue.button,
.ui.blue.buttons .button,
.ui.blue.basic.button:hover {
  background-color: var(--ss-accent) !important;
  background-image: none !important;
  color: #fff !important;
  text-shadow: none !important;
  border-radius: 10px !important;
  font-weight: 700 !important;
}

.ui.primary.button:hover,
.ui.primary.buttons .button:hover,
.ui.blue.button:hover,
.ui.blue.buttons .button:hover {
  background-color: var(--ss-accent-hover) !important;
}

.ui.blue.basic.button,
.ui.blue.basic.buttons .button {
  color: var(--ss-accent) !important;
  box-shadow: 0 0 0 1px var(--ss-accent) inset !important;
}

/* Links & labels */
a { color: var(--ss-accent); }
a:hover { color: var(--ss-accent-hover); }

.ui.blue.label,
.ui.primary.label {
  background-color: var(--ss-accent) !important;
  border-color: var(--ss-accent) !important;
  color: #fff !important;
}

/* Icons that were blue */
i.blue.icon,
.ui.blue.icon {
  color: var(--ss-accent) !important;
}

/* Tables */
.ui.table thead th {
  background: #fafbfc !important;
  color: var(--ss-muted) !important;
  font-weight: 700 !important;
}

.ui.table tbody tr:hover td {
  background: var(--ss-accent-soft) !important;
}

/* Inputs */
.ui.input > input:focus,
.ui.form input:focus,
.ui.form textarea:focus {
  border-color: var(--ss-accent) !important;
}

.ui.checkbox input:checked ~ label:before,
.ui.checkbox input:checked ~ .box:before {
  background: var(--ss-accent) !important;
  border-color: var(--ss-accent) !important;
}

h1, h2, h3, .ui.header {
  font-weight: 800 !important;
  letter-spacing: -0.02em;
}

.ui.segment, .ui.card {
  border-radius: 12px !important;
}

.ui.progress .bar {
  background: var(--ss-accent) !important;
}
EOF

# Strip previous broken import / marker, then APPEND full theme (not @import — ignored at EOF)
grep -v 'skyscale-theme' "$CSS" | grep -v 'SkyScale theme' > /tmp/custom.css.clean
cp /tmp/custom.css.clean "$CSS"
printf '\n\n' >> "$CSS"
cat "$THEME" >> "$CSS"

# Also keep standalone file for bind-mount
cp "$THEME" /storage/usbdisk1/mikopbx/tmp/skyscale-theme.css 2>/dev/null || true

echo OK
wc -l "$CSS"
tail -n 5 "$CSS"
