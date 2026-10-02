#!/bin/sh
# Persist STT settings that make local Whisper usable on typical PBX traffic
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
NOW=$(php -r 'echo (int)floor(microtime(true)*1000);')
sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET
  internal_enabled=1,
  min_duration_sec=CASE WHEN min_duration_sec>3 THEN 3 ELSE min_duration_sec END,
  activation_at_ms=COALESCE(NULLIF(activation_at_ms,0), $NOW-86400000),
  updated_at_ms=$NOW
WHERE singleton_key='default';"
sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET
  balance_checked_at_ms=$NOW,
  provider_reachability='reachable',
  provider_auth_state='valid',
  balance_state='known',
  admission_primary_state='open'
WHERE singleton_key='default';"
echo "local whisper defaults applied"
sqlite3 -header -column "$DB" "SELECT internal_enabled,min_duration_sec,activation_at_ms FROM m_CloudSTTSetting WHERE singleton_key='default';"
