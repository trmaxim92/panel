#!/bin/sh
# Install faster-whisper into whisper-pkgs and start sidecar.
set -e
SRC="${1:-/tmp/stt-patches}"
MOD="/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText"
PRIV="$MOD/db/private"
SIDECAR_DST="$PRIV/whisper-sidecar"
TARGET="$PRIV/whisper-pkgs"

if [ ! -d "$MOD" ]; then
  echo "ModuleCloudSpeechToText not installed; skip whisper sidecar" >&2
  exit 0
fi

mkdir -p "$PRIV" "$SIDECAR_DST" "$PRIV/whisper-staging" "$TARGET"
cp -f "$SRC/whisper-sidecar/server.py" "$SIDECAR_DST/server.py"
cp -f "$SRC/whisper-sidecar/run.sh" "$SIDECAR_DST/run.sh"
cp -f "$SRC/whisper-sidecar/ensure-running.sh" "$SIDECAR_DST/ensure-running.sh"
chmod +x "$SIDECAR_DST/run.sh" "$SIDECAR_DST/ensure-running.sh"

if [ ! -f "$PRIV/skyscale-provider.json" ]; then
  cat >"$PRIV/skyscale-provider.json" <<'EOF'
{
  "provider_mode": "local_whisper",
  "sidecar_url": "http://127.0.0.1:8791",
  "whisper_model": "base",
  "whisper_language": "ru"
}
EOF
fi
chown www:disk "$PRIV/skyscale-provider.json" 2>/dev/null || chown www:www "$PRIV/skyscale-provider.json" 2>/dev/null || true
chmod 664 "$PRIV/skyscale-provider.json" 2>/dev/null || true

export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"

if ! PYTHONPATH="$TARGET" python3 -c 'import faster_whisper' 2>/dev/null; then
  echo "== installing faster-whisper into $TARGET =="
  if ! python3 -m pip --version >/dev/null 2>&1; then
    wget -q -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
    python3 /tmp/get-pip.py --break-system-packages --trusted-host pypi.org --trusted-host files.pythonhosted.org
  fi
  python3 -m pip install --break-system-packages --root-user-action=ignore \
    --trusted-host pypi.org --trusted-host files.pythonhosted.org \
    --target "$TARGET" "faster-whisper>=1.0.0"
fi

PYTHONPATH="$TARGET" python3 -c 'import faster_whisper; print("faster-whisper ok")'

# Ensure tombstone HMAC key exists so discovery can create jobs in local mode
KEY="$PRIV/tombstone-hmac.key"
if [ ! -f "$KEY" ]; then
  php -r 'file_put_contents($argv[1], bin2hex(random_bytes(32)));' "$KEY" 2>/dev/null || \
    (head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$KEY")
  chmod 600 "$KEY" 2>/dev/null || true
fi
DB="$MOD/db/module.db"
if [ -f "$DB" ] && [ -f "$KEY" ]; then
  sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET tombstone_hmac_key_ref='$KEY' WHERE singleton_key='default' AND (tombstone_hmac_key_ref IS NULL OR tombstone_hmac_key_ref='');" 2>/dev/null || true
fi
if [ -f "$DB" ]; then
  NOW=$(php -r 'echo (int)floor(microtime(true)*1000);' 2>/dev/null || date +%s000)
  sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET
    internal_enabled=1,
    min_duration_sec=CASE WHEN min_duration_sec IS NULL OR min_duration_sec>3 THEN 3 ELSE min_duration_sec END,
    activation_at_ms=COALESCE(NULLIF(activation_at_ms,0), $NOW),
    incoming_enabled=1,
    outgoing_enabled=1
  WHERE singleton_key='default';" 2>/dev/null || true
fi

pkill -f "whisper-sidecar/server.py" 2>/dev/null || true
sleep 1
rm -f "$PRIV/whisper-sidecar.pid"
sh "$SIDECAR_DST/ensure-running.sh" || true
echo "whisper sidecar install done"
