#!/bin/sh
set -e
PRIV=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/private
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
KEY="$PRIV/tombstone-hmac.key"
mkdir -p "$PRIV"
chmod 700 "$PRIV" 2>/dev/null || true
if [ ! -f "$KEY" ]; then
  php -r 'file_put_contents($argv[1], bin2hex(random_bytes(32)));' "$KEY"
fi
chmod 600 "$KEY" 2>/dev/null || true
sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET tombstone_hmac_key_ref='$KEY', row_version=row_version+1, updated_at_ms=$(php -r 'echo (int)floor(microtime(true)*1000);') WHERE singleton_key='default';"
echo "tombstone key ready: $KEY"
sqlite3 "$DB" "SELECT tombstone_hmac_key_ref FROM m_CloudSTTSetting WHERE singleton_key='default';"
# clear scan error
sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET last_scan_error_code=NULL, cursor_endtime_ms=0, cursor_cdr_id=0 WHERE singleton_key='default';"
sleep 10
sqlite3 -header -column "$DB" "SELECT last_scan_error_code,last_scan_completed_at_ms,cursor_endtime_ms FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"
echo jobs=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTJob;")
sqlite3 -header -column "$DB" "SELECT id,state,reason_code,substr(logical_call_id,1,48) FROM m_CloudSTTJob ORDER BY id DESC LIMIT 10;"
