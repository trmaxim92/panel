#!/bin/sh
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
# Rewind discovery so existing monitor files get reconsidered
sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET cursor_endtime_ms=0, cursor_cdr_id=0, late_cursor_endtime_ms=0, late_cursor_cdr_id=0 WHERE singleton_key='default';"
echo "discovery cursor reset"
# Wait for discovery/submit cycles
i=0
while [ "$i" -lt 30 ]; do
  i=$((i+1))
  N=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTJob;")
  echo "t=$i jobs=$N"
  if [ "$N" -gt 0 ]; then
    sqlite3 -header -column "$DB" "SELECT id,state,reason_code,substr(logical_call_id,1,40) AS call_id,recording_relpath FROM m_CloudSTTJob ORDER BY id DESC LIMIT 10;"
    break
  fi
  sleep 2
done
sqlite3 -header -column "$DB" "SELECT COUNT(*) AS transcripts FROM m_CloudSTTCallTranscript WHERE current_revision_id IS NOT NULL;"
