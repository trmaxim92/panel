#!/bin/sh
DB=/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/module.db
sqlite3 -header -column "$DB" "SELECT last_scan_started_at_ms,last_scan_completed_at_ms,last_scan_error_code,admission_primary_state,admission_reasons_json,cursor_endtime_ms,cursor_cdr_id FROM m_CloudSTTDiscoveryState WHERE singleton_key='default';"
echo skips=$(sqlite3 "$DB" "SELECT COUNT(*) FROM m_CloudSTTDiscoverySkip;")
# CDR sample
php -r '
require "/usr/www/src/Common/Config/ClassLoader.php";
' 2>/dev/null || true
ls /var/log/asterisk 2>/dev/null | head
# module log
find /storage/usbdisk1/mikopbx -name '*ModuleCloudSpeech*' -type f 2>/dev/null | head
ls /storage/usbdisk1/mikopbx/log 2>/dev/null | head
