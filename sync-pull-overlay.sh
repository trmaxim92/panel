#!/bin/sh
# Build deployable overlay tree mirroring container paths under /usr/www
set -e
OUT=/tmp/mikopbx-overlay
rm -rf "$OUT"
WWW="$OUT/usr/www"
mkdir -p "$WWW"

# --- Views ---
mkdir -p "$WWW/src/AdminCabinet/Views"
cp -a /usr/www/src/AdminCabinet/Views/CallDetailRecords "$WWW/src/AdminCabinet/Views/"
if [ -d /usr/www/src/AdminCabinet/Views/CallRecordings ]; then
  cp -a /usr/www/src/AdminCabinet/Views/CallRecordings "$WWW/src/AdminCabinet/Views/"
fi

# --- Controllers ---
mkdir -p "$WWW/src/AdminCabinet/Controllers"
cp -a /usr/www/src/AdminCabinet/Controllers/CallDetailRecordsController.php "$WWW/src/AdminCabinet/Controllers/" 2>/dev/null || true
cp -a /usr/www/src/AdminCabinet/Controllers/CallRecordingsController.php "$WWW/src/AdminCabinet/Controllers/" 2>/dev/null || true

# --- Providers / menu ---
mkdir -p "$WWW/src/AdminCabinet/Providers" "$WWW/src/AdminCabinet/Library"
cp -a /usr/www/src/AdminCabinet/Providers/AssetProvider.php "$WWW/src/AdminCabinet/Providers/"
cp -a /usr/www/src/AdminCabinet/Library/Elements.php "$WWW/src/AdminCabinet/Library/" 2>/dev/null || true

# --- CDR API ---
mkdir -p "$WWW/src/PBXCoreREST/Lib/Cdr"
cp -a /usr/www/src/PBXCoreREST/Lib/Cdr/GetListAction.php "$WWW/src/PBXCoreREST/Lib/Cdr/"

# --- Messages ---
mkdir -p "$WWW/src/Common/Messages/ru" "$WWW/src/Common/Messages/en"
cp -a /usr/www/src/Common/Messages/ru/Common.php "$WWW/src/Common/Messages/ru/"
cp -a /usr/www/src/Common/Messages/en/Common.php "$WWW/src/Common/Messages/en/"

# --- Frontend assets ---
AS="$WWW/sites/admin-cabinet/assets"
mkdir -p "$AS/js/pbx" "$AS/js/src" "$AS/css"
cp -a /usr/www/sites/admin-cabinet/assets/js/pbx/CallDetailRecords "$AS/js/pbx/"
cp -a /usr/www/sites/admin-cabinet/assets/js/src/CallDetailRecords "$AS/js/src/" 2>/dev/null || true
if [ -d /usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings ]; then
  cp -a /usr/www/sites/admin-cabinet/assets/js/pbx/CallRecordings "$AS/js/pbx/"
fi
if [ -d /usr/www/sites/admin-cabinet/assets/js/src/CallRecordings ]; then
  cp -a /usr/www/sites/admin-cabinet/assets/js/src/CallRecordings "$AS/js/src/"
fi
# custom.css (theme + markers)
cp -a /offload/rootfs/usr/www/sites/admin-cabinet/assets/css/custom.css "$AS/css/custom.css" 2>/dev/null \
  || cp -a /usr/www/sites/admin-cabinet/assets/css/custom.css "$AS/css/custom.css"

# CDR player css if present
mkdir -p "$AS/css/CallDetailRecords"
cp -a /usr/www/sites/admin-cabinet/assets/css/CallDetailRecords/. "$AS/css/CallDetailRecords/" 2>/dev/null || true

# --- Config snapshot (no SIP secrets) ---
mkdir -p "$OUT/config"
sqlite3 /cf/conf/mikopbx.db <<'SQL' > "$OUT/config/routing-snapshot.txt"
.headers on
.mode column
SELECT '=== QUEUES ===';
SELECT uniqid,name,extension FROM m_CallQueues;
SELECT '=== QUEUE MEMBERS ===';
SELECT queue,extension,priority FROM m_CallQueueMembers;
SELECT '=== INCOMING ===';
SELECT id,rulename,number,extension,provider,priority,action FROM m_IncomingRoutingTable;
SELECT '=== OUTGOING ===';
SELECT id,rulename,numberbeginswith,restnumbers,providerid,priority FROM m_OutgoingRoutingTable;
SELECT '=== TRUNKS (no secrets) ===';
SELECT uniqid,username,host,registration_type,fromuser,fromdomain,description,disabled FROM m_Sip WHERE uniqid LIKE 'SIP-TRUNK%';
SELECT '=== EXTENSIONS SIP ===';
SELECT number,callerid FROM m_Extensions WHERE type='SIP' ORDER BY number;
SQL

{
  echo "pulled_at=$(date -Iseconds)"
  echo "host=$(hostname)"
  asterisk -rx "core show version" 2>/dev/null | head -1
} > "$OUT/META.txt"

find "$OUT" -type f | sort > "$OUT/MANIFEST.txt"
cd /tmp
tar czf /tmp/mikopbx-overlay.tgz -C /tmp mikopbx-overlay
ls -lh /tmp/mikopbx-overlay.tgz
echo "files=$(wc -l < "$OUT/MANIFEST.txt")"
