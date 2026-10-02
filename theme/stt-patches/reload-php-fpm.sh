#!/bin/sh
# Reload PHP-FPM so opcache picks up new Controllers
if [ -f /var/run/php-fpm.pid ]; then
  kill -USR2 "$(cat /var/run/php-fpm.pid)" 2>/dev/null && echo "USR2 via pidfile" && exit 0
fi
master=$(ps | awk '/php-fpm: master/{print $1; exit}')
if [ -n "$master" ]; then
  kill -USR2 "$master" 2>/dev/null && echo "USR2 master=$master" && exit 0
fi
# Fallback: restart pool workers
pkill -f 'php-fpm: pool' 2>/dev/null || true
sleep 1
echo "pool workers recycled"
ps | grep php-fpm | grep -v grep | head -5
