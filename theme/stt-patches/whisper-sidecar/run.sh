#!/bin/sh
# Start sidecar using site-packages installed into whisper-pkgs (no fragile venv).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGS="${WHISPER_PKGS:-$ROOT/whisper-pkgs}"
export PYTHONPATH="${PKGS}${PYTHONPATH:+:$PYTHONPATH}"
export WHISPER_HOST="${WHISPER_HOST:-127.0.0.1}"
export WHISPER_PORT="${WHISPER_PORT:-8791}"
export WHISPER_MODEL="${WHISPER_MODEL:-base}"
export WHISPER_LANGUAGE="${WHISPER_LANGUAGE:-ru}"
export WHISPER_ALLOWED_PREFIXES="${WHISPER_ALLOWED_PREFIXES:-/storage/usbdisk1/mikopbx,/var/spool/mikopbx/storage,/tmp}"
exec python3 "$(dirname "$0")/server.py"
