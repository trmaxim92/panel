#!/bin/sh
set -e
PRIV=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/private
TARGET="$PRIV/whisper-pkgs"
SIDECAR="$PRIV/whisper-sidecar"
LOG="$PRIV/whisper-sidecar.log"
PIDFILE="$PRIV/whisper-sidecar.pid"

export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"

mkdir -p "$TARGET" "$SIDECAR"

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

PYTHONPATH="$TARGET" python3 -c 'import faster_whisper; print("faster-whisper ok", faster_whisper.__file__)'

# Wrapper launcher that injects PYTHONPATH
cat > "$SIDECAR/run.sh" <<EOF
#!/bin/sh
export PYTHONPATH="$TARGET\${PYTHONPATH:+:\$PYTHONPATH}"
export WHISPER_HOST="\${WHISPER_HOST:-127.0.0.1}"
export WHISPER_PORT="\${WHISPER_PORT:-8791}"
export WHISPER_MODEL="\${WHISPER_MODEL:-base}"
export WHISPER_LANGUAGE="\${WHISPER_LANGUAGE:-ru}"
export WHISPER_ALLOWED_PREFIXES="\${WHISPER_ALLOWED_PREFIXES:-/storage/usbdisk1/mikopbx,/var/spool/mikopbx/storage,/tmp}"
exec python3 "\$(dirname "\$0")/server.py"
EOF
chmod +x "$SIDECAR/run.sh"

pkill -f "whisper-sidecar/server.py" 2>/dev/null || true
sleep 1
rm -f "$PIDFILE"
nohup sh "$SIDECAR/run.sh" >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
sleep 2
wget -q -O - http://127.0.0.1:8791/health
echo
echo "sidecar pid=$(cat "$PIDFILE")"
