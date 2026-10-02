#!/bin/sh
# Ensure Whisper sidecar is running (1 worker, CPU int8, whisper-pkgs PYTHONPATH).
set -e
MOD_ROOT="/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText"
SIDECAR_DIR="$MOD_ROOT/db/private/whisper-sidecar"
LOG="$MOD_ROOT/db/private/whisper-sidecar.log"
PIDFILE="$MOD_ROOT/db/private/whisper-sidecar.pid"
PORT="${WHISPER_PORT:-8791}"

mkdir -p "$(dirname "$LOG")" "$SIDECAR_DIR"

health_ok() {
  wget -q -O - "http://127.0.0.1:${PORT}/health" 2>/dev/null | grep -q '"ok"'
}

if [ -f "$PIDFILE" ]; then
  oldpid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    if health_ok; then
      echo "whisper-sidecar already running pid=$oldpid"
      exit 0
    fi
    kill "$oldpid" 2>/dev/null || true
    sleep 1
  fi
fi

if health_ok; then
  echo "whisper-sidecar healthy on :$PORT (external)"
  exit 0
fi

export WHISPER_HOST=127.0.0.1
export WHISPER_PORT="$PORT"
export WHISPER_MODEL="${WHISPER_MODEL:-base}"
export WHISPER_LANGUAGE="${WHISPER_LANGUAGE:-ru}"
export WHISPER_JOB_TIMEOUT_SEC="${WHISPER_JOB_TIMEOUT_SEC:-1800}"
export WHISPER_ALLOWED_PREFIXES="${WHISPER_ALLOWED_PREFIXES:-/storage/usbdisk1/mikopbx,/var/spool/mikopbx/storage,/tmp}"
export WHISPER_PKGS="${WHISPER_PKGS:-$MOD_ROOT/db/private/whisper-pkgs}"

nohup sh "$SIDECAR_DIR/run.sh" >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
sleep 2
if health_ok; then
  echo "whisper-sidecar started pid=$(cat "$PIDFILE")"
  exit 0
fi
echo "whisper-sidecar failed to become healthy; see $LOG" >&2
tail -n 40 "$LOG" 2>/dev/null || true
exit 1
