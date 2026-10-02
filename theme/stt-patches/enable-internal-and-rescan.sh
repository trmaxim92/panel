#!/bin/sh
set -e
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db

# Enable internal calls (204↔205), lower min duration for short test calls
sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET
  internal_enabled=1,
  min_duration_sec=1,
  incoming_enabled=1,
  outgoing_enabled=1,
  user_paused=0,
  activated=1,
  rules_version=rules_version+1,
  rules_effective_at_ms=0,
  updated_at_ms=$(php -r 'echo (int)floor(microtime(true)*1000);')
WHERE singleton_key='default';"

# Rewind discovery cursor to reprocess existing CDR with recordings
sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET
  cursor_endtime_ms=0,
  cursor_cdr_id=0,
  late_cursor_endtime_ms=0,
  late_cursor_cdr_id=0,
  last_scan_error_code=NULL,
  next_provider_check_at_ms=0,
  admission_primary_state='open',
  maintenance_mode=0
WHERE singleton_key='default';"

# Clear old skips so decisions can be remade
sqlite3 "$DB" "DELETE FROM m_CloudSTTDiscoverySkip;"

echo "== settings =="
sqlite3 -header -column "$DB" "SELECT internal_enabled,min_duration_sec,incoming_enabled,outgoing_enabled,activated,user_paused FROM m_CloudSTTSetting WHERE singleton_key='default';"

# Restart discovery worker to pick up immediately
pkill -f WorkerCloudSpeechToTextDiscovery 2>/dev/null || true
sleep 3

echo "waiting for jobs..."
i=0
while [ "$i" -lt 45 ]; do
  i=$((i+1))
  N=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTJob;")
  T=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTCallTranscript;")
  echo "t=$i jobs=$N transcripts=$T"
  if [ "$N" -gt 0 ]; then
    sqlite3 -header -column "$DB" "SELECT id,state,reason_code,substr(logical_call_id,1,40) AS call_id,substr(COALESCE(recording_relpath,''),1,60) AS rec FROM m_CloudSTTJob ORDER BY id DESC LIMIT 12;"
  fi
  if [ "$T" -gt 0 ]; then
    sqlite3 -header -column "$DB" "SELECT id,logical_call_id,public_id,completeness_status,current_revision_id FROM m_CloudSTTCallTranscript ORDER BY id DESC LIMIT 8;"
    break
  fi
  sleep 2
done

echo "== discovery after =="
sqlite3 -header -column "$DB" "SELECT cursor_cdr_id,last_scan_error_code,last_scan_completed_at_ms,provider_reachability,balance_state,admission_primary_state FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"
echo "== skips =="
sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTDiscoverySkip;"
echo DONE
