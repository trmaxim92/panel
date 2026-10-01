#!/bin/sh
set -e
CSS=/offload/rootfs/usr/www/sites/admin-cabinet/assets/css/custom.css

# Remove previous hover-fix marker block if re-run
grep -v 'ss-hover-fix' "$CSS" > /tmp/custom.css.nofix || cp "$CSS" /tmp/custom.css.nofix
cp /tmp/custom.css.nofix "$CSS"

cat >> "$CSS" <<'EOF'

/* ss-hover-fix: category groups (Модули/Обслуживание) must not highlight on hover */
.ui.vertical.inverted.menu > .item:hover,
.ui.vertical.menu.inverted.sidebar-menu > .item:hover,
.sidebar-menu.ui.vertical.inverted.menu > .item:hover {
  background: transparent !important;
  color: inherit !important;
}

.ui.vertical.inverted.menu > .item > .header,
.sidebar-menu > .item > .header {
  background: transparent !important;
  color: #9aa0b2 !important;
  cursor: default !important;
}

/* Only clickable menu links get hover */
.ui.vertical.inverted.menu a.item:hover,
.sidebar-menu a.item:hover {
  background: #2a2e3b !important;
  color: #fff !important;
  border-radius: 8px;
}
EOF

echo OK
tail -n 25 "$CSS"
