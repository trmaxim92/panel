#!/bin/sh
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
sqlite3 "$DB" "UPDATE m_CloudSTTSetting SET activated=1,user_paused=0 WHERE singleton_key='default';"
sqlite3 "$DB" "UPDATE m_CloudSTTDiscoveryState SET next_provider_check_at_ms=0, maintenance_mode=0 WHERE singleton_key='default';"
sleep 8
echo "== health =="
sqlite3 -header -column "$DB" "SELECT provider_reachability,provider_auth_state,balance_state,balance_amount_decimal,balance_currency,provider_check_failures,admission_primary_state FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"
echo "== jobs =="
sqlite3 -header -column "$DB" "SELECT id,state,reason_code,logical_call_id FROM m_CloudSTTJob ORDER BY id DESC LIMIT 8;"
