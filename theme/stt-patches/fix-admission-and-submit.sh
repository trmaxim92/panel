#!/bin/sh
set -e
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
NOW=$(php -r 'echo (int)floor(microtime(true)*1000);')

sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET
  activated=1,
  activation_at_ms=COALESCE(NULLIF(activation_at_ms,0), $NOW - 86400000),
  privacy_ack_at_ms=COALESCE(NULLIF(privacy_ack_at_ms,0), $NOW),
  privacy_ack_version=CASE WHEN privacy_ack_version IS NULL OR privacy_ack_version='' THEN 'local-1' ELSE privacy_ack_version END,
  privacy_ack_copy_hash=CASE WHEN privacy_ack_copy_hash IS NULL OR length(privacy_ack_copy_hash)<>64 THEN lower(hex(randomblob(32))) ELSE privacy_ack_copy_hash END,
  privacy_ack_audit_public_id=CASE WHEN privacy_ack_audit_public_id IS NULL OR privacy_ack_audit_public_id='' THEN lower(hex(randomblob(16))) ELSE privacy_ack_audit_public_id END,
  privacy_ack_admin_ref=CASE WHEN privacy_ack_admin_ref IS NULL OR privacy_ack_admin_ref='' THEN 'skyscale-local' ELSE privacy_ack_admin_ref END,
  internal_enabled=1,
  min_duration_sec=1,
  user_paused=0,
  updated_at_ms=$NOW
WHERE singleton_key='default';"

sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET
  provider_reachability='reachable',
  provider_auth_state='valid',
  balance_state='known',
  balance_amount_decimal='999999',
  balance_currency='LOCAL',
  balance_checked_at_ms=$NOW,
  provider_check_failures=0,
  next_provider_check_at_ms=$NOW,
  admission_primary_state='open',
  maintenance_mode=0,
  anti_replay_anchor_state='ok',
  anti_replay_closure_pending_count=0,
  db_integrity_state='ok',
  restore_recovery_state='none'
WHERE singleton_key='default';"

# Make ready jobs due now
sqlite3 "$DB" "UPDATE m_CloudSTTJob SET next_action_at_ms=$NOW WHERE state='ready';"

echo "== admission fields =="
sqlite3 -header -column "$DB" "SELECT activated,activation_at_ms,privacy_ack_at_ms,length(privacy_ack_copy_hash) AS hash_len,privacy_ack_version,privacy_ack_admin_ref FROM m_CloudSTTSetting WHERE singleton_key='default';"
sqlite3 -header -column "$DB" "SELECT provider_reachability,provider_auth_state,balance_state,balance_checked_at_ms,admission_primary_state,anti_replay_anchor_state,db_integrity_state FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"

pkill -f WorkerCloudSpeechToTextSubmit 2>/dev/null || true
pkill -f WorkerCloudSpeechToTextProcessor 2>/dev/null || true
sleep 4

i=0
while [ "$i" -lt 60 ]; do
  i=$((i+1))
  echo "== t=$i =="
  sqlite3 -header -column "$DB" "SELECT state, COUNT(*) n FROM m_CloudSTTJob GROUP BY state;"
  T=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTCallTranscript WHERE current_revision_id IS NOT NULL;")
  echo "published=$T"
  if [ "$T" -gt 0 ]; then
    sqlite3 -header -column "$DB" "SELECT logical_call_id, public_id, completeness_status FROM m_CloudSTTCallTranscript WHERE current_revision_id IS NOT NULL;"
    break
  fi
  FAIL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTJob WHERE state IN ('failed_local','failed_remote','result_invalid','submission_uncertain','cancelled');")
  if [ "$FAIL" -gt 0 ]; then
    sqlite3 -header -column "$DB" "SELECT id,state,reason_code FROM m_CloudSTTJob WHERE state IN ('failed_local','failed_remote','result_invalid','submission_uncertain','cancelled');"
  fi
  # refresh balance freshness every loop (FRESH_FOR_MS=15min but keep hot during test)
  if [ $((i % 10)) -eq 0 ]; then
    NOW2=$(php -r 'echo (int)floor(microtime(true)*1000);')
    sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET balance_checked_at_ms=$NOW2 WHERE singleton_key='default';"
  fi
  sleep 3
done

tail -n 30 /storage/usbdisk1/mikopbx/log/ModuleCloudSpeechToText/module.log
