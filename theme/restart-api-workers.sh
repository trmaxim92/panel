#!/bin/sh
# Kill stale API workers and respawn SafeScripts
kill -9 1094 1096 1098 87004 2>/dev/null || true
# kill any WorkerApiCommands still running
for pid in $(ls /proc 2>/dev/null | grep '^[0-9]\+$'); do
  cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null || true)
  case "$cmd" in
    *WorkerApiCommands*) kill -9 "$pid" 2>/dev/null || true ;;
  esac
done
rm -f /var/run/php-workers/MikoPBX-PBXCoreREST-Workers-WorkerApiCommands*.pid

php -r 'if(function_exists("opcache_reset")){opcache_reset();}'

# Start SafeScripts which respawns workers
nohup php /usr/www/src/Core/Workers/Cron/WorkerSafeScriptsCore.php start >/tmp/safe.log 2>&1 &
sleep 6

echo "== api pids =="
for f in /var/run/php-workers/MikoPBX-PBXCoreREST-Workers-WorkerApiCommands*.pid; do
  [ -f "$f" ] || continue
  pid=$(cat "$f")
  if [ -d "/proc/$pid" ]; then echo "OK $f=$pid"; else echo "DEAD $f=$pid"; fi
done

echo "== safe log =="
tail -30 /tmp/safe.log 2>/dev/null || true

# Also start WorkerApiCommands directly as fallback
if ! ls /var/run/php-workers/MikoPBX-PBXCoreREST-Workers-WorkerApiCommands.pid >/dev/null 2>&1; then
  echo "starting WorkerApiCommands manually"
  nohup php /usr/www/src/PBXCoreREST/Workers/WorkerApiCommands.php start >/tmp/wapi1.log 2>&1 &
  nohup php /usr/www/src/PBXCoreREST/Workers/WorkerApiCommands.php start >/tmp/wapi2.log 2>&1 &
  sleep 3
fi

for f in /var/run/php-workers/MikoPBX-PBXCoreREST-Workers-WorkerApiCommands*.pid; do
  [ -f "$f" ] || continue
  echo "final $f=$(cat "$f")"
done
echo DONE
