#!/bin/sh
grep -R -n "function getMenu" /usr/www/src --include="*.php" 2>/dev/null | head -20
echo ----
# likely Elements class
find /usr/www/src -name '*Elements*' 2>/dev/null
find /usr/www/src -name '*Menu*' 2>/dev/null | head
