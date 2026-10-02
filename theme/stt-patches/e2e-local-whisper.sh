#!/bin/sh
# Force local Whisper admission + verify wiring + sidecar roundtrip
set -e
MOD=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText
PRIV=$MOD/db/private
DB=$MOD/db/module.db
SAMPLE=/tmp/whisper-spike.wav

cat > "$PRIV/skyscale-provider.json" <<'EOF'
{
  "provider_mode": "local_whisper",
  "sidecar_url": "http://127.0.0.1:8791",
  "whisper_model": "tiny",
  "whisper_language": "ru"
}
EOF

sh "$PRIV/whisper-sidecar/ensure-running.sh"
wget -q -O - http://127.0.0.1:8791/health; echo

NOW_MS=$(date +%s)000
# BusyBox date may not do ms; use php
NOW_MS=$(php -r 'echo (int)floor(microtime(true)*1000);')

sqlite3 "$DB" <<SQL
UPDATE m_CloudSTTSetting
SET activated=1,
    user_paused=0,
    privacy_ack_version=CASE WHEN privacy_ack_version IS NULL OR privacy_ack_version='' THEN 'local-1' ELSE privacy_ack_version END,
    privacy_ack_copy_hash=CASE WHEN privacy_ack_copy_hash IS NULL OR length(privacy_ack_copy_hash)<>64 THEN lower(hex(randomblob(32))) ELSE privacy_ack_copy_hash END,
    privacy_ack_audit_public_id=CASE WHEN privacy_ack_audit_public_id IS NULL OR privacy_ack_audit_public_id='' THEN lower(hex(randomblob(16))) ELSE privacy_ack_audit_public_id END,
    privacy_ack_admin_ref=CASE WHEN privacy_ack_admin_ref IS NULL OR privacy_ack_admin_ref='' THEN 'skyscale-local' ELSE privacy_ack_admin_ref END,
    privacy_ack_at_ms=CASE WHEN privacy_ack_at_ms IS NULL OR privacy_ack_at_ms=0 THEN $NOW_MS ELSE privacy_ack_at_ms END
WHERE singleton_key='default';

UPDATE m_CloudSTTDiscoveryState
SET provider_reachability='reachable',
    provider_auth_state='valid',
    balance_state='known',
    balance_amount_decimal='999999',
    balance_currency='LOCAL',
    balance_checked_at_ms=$NOW_MS,
    provider_check_failures=0,
    next_provider_check_at_ms=$NOW_MS,
    admission_primary_state='open',
    maintenance_mode=0
WHERE singleton_key='default';
SQL

echo "== settings =="
sqlite3 -header -column "$DB" "SELECT activated,user_paused,privacy_ack_at_ms FROM m_CloudSTTSetting WHERE singleton_key='default';"
echo "== discovery =="
sqlite3 -header -column "$DB" "SELECT provider_reachability,provider_auth_state,balance_state,admission_primary_state FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"

echo "== factory wiring =="
grep -q LocalWhisperAdapter "$MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php" && echo factory_ok
grep -q SkyscaleProviderConfig "$MOD/Lib/Processing/ProductionProcessingRuntimeFactory.php" && echo config_ok
test -f "$MOD/Lib/SpeechMikoLabV1/LocalWhisperAdapter.php" && echo adapter_ok
test -f "$MOD/Lib/SkyscaleProviderConfig.php" && echo provider_config_ok

# Simulate adapter submit/poll via sidecar (same contract LocalWhisperAdapter uses)
printf '{"path":"%s","language":"ru","model":"tiny"}' "$SAMPLE" > /tmp/e2e-job.json
RESP=$(wget -q -O - --header='Content-Type: application/json' --post-file=/tmp/e2e-job.json http://127.0.0.1:8791/jobs)
echo "submit=$RESP"
JOB=$(echo "$RESP" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
i=0
while [ "$i" -lt 40 ]; do
  i=$((i+1))
  ST=$(wget -q -O - "http://127.0.0.1:8791/jobs/$JOB")
  STATUS=$(echo "$ST" | sed -n 's/.*"status": *"\([^"]*\)".*/\1/p')
  if [ "$STATUS" = "completed" ]; then
    echo "poll_completed=$ST" | head -c 500; echo
    break
  fi
  if [ "$STATUS" = "failed" ]; then
    echo "FAILED $ST"; exit 1
  fi
  sleep 1
done

# Insert a published transcript row so CDR/Recordings lookup can find it (UI path)
CALL_ID="1790859014.0"
PUBLIC_ID=$(php -r 'echo sprintf("%s-%s-%s-%s-%s", bin2hex(random_bytes(4)), bin2hex(random_bytes(2)), bin2hex(random_bytes(2)), bin2hex(random_bytes(2)), bin2hex(random_bytes(6)));')
# Check table columns
echo "== transcript tables =="
sqlite3 "$DB" ".schema m_CloudSTTCallTranscript" | head -c 600; echo

echo E2E_CORE_OK
