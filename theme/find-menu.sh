#!/bin/sh
grep -R -n "header item\|item header\|menuGroups\|groupName\|sidebar-menu" \
  /offload/rootfs/usr/www/sites/admin-cabinet/assets/js/pbx/main \
  /usr/www/src/AdminCabinet 2>/dev/null | head -50
