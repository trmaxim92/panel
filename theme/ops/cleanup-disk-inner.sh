#!/bin/sh
# Runs INSIDE mikopbx container
set -eu
KEEP_ROTATED="${KEEP_ROTATED:-2}"
MAX_ACTIVE_MB="${MAX_ACTIVE_MB:-200}"
LOG=/storage/usbdisk1/mikopbx/log/asterisk

echo "== asterisk rotations (keep index < $KEEP_ROTATED) =="
if [ -d "$LOG" ]; then
  cd "$LOG"
  for base in verbose security_log messages full error notice warning debug; do
    for f in ./$base.*; do
      [ -e "$f" ] || continue
      name=${f#./}
      case "$name" in
        "$base".*) ;;
        *) continue ;;
      esac
      rest=${name#"$base".}
      idx=${rest%%[!0-9]*}
      case "$idx" in
        ''|*[!0-9]*) continue ;;
      esac
      if [ "$idx" -ge "$KEEP_ROTATED" ]; then
        echo "rm $name"
        rm -f -- "$name"
      fi
    done
  done
fi

echo "== fail2ban/system/nginx old rotations =="
for dir in /storage/usbdisk1/mikopbx/log/fail2ban /storage/usbdisk1/mikopbx/log/system /storage/usbdisk1/mikopbx/log/nginx; do
  [ -d "$dir" ] || continue
  find "$dir" -type f \( -name '*.gz' -o -name '*.[2-9]' -o -name '*.[1-9][0-9]' -o -name '*.old' \) -print -delete 2>/dev/null || true
done

echo "== truncate oversized active logs =="
for f in "$LOG/verbose" "$LOG/security_log" "$LOG/messages"; do
  [ -f "$f" ] || continue
  sz=$(du -m "$f" | awk '{print $1}')
  if [ "$sz" -gt "$MAX_ACTIVE_MB" ]; then
    echo "truncate $f (${sz}M -> last ${MAX_ACTIVE_MB}M)"
    tail -c $((MAX_ACTIVE_MB * 1024 * 1024)) "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
done

echo "== tmp / volt / staging =="
rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true
find /storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/private/whisper-staging \
  -type f -mtime +2 -delete 2>/dev/null || true
f=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/private/whisper-sidecar.log
if [ -f "$f" ]; then
  sz=$(du -m "$f" | awk '{print $1}')
  if [ "$sz" -gt 20 ]; then
    : > "$f"
    echo "truncated whisper-sidecar.log"
  fi
fi

echo "== pip cache =="
rm -rf /root/.cache/pip 2>/dev/null || true

echo "== sizes after =="
du -sh /storage/usbdisk1/mikopbx/log /storage/usbdisk1/mikopbx/log/asterisk /root/.cache 2>/dev/null || true
df -h / | tail -1
echo DONE_INNER
