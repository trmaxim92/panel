#!/bin/sh
set -eu
docker exec mikopbx sh -c '
echo === logger.conf ===
ls -la /etc/asterisk/logger.conf 2>/dev/null || true
if [ -f /etc/asterisk/logger.conf ]; then
  grep -nE "rotate|verbose|console|messages|security|general" /etc/asterisk/logger.conf | head -50
fi
echo === logger files ===
ls -lah /storage/usbdisk1/mikopbx/log/asterisk | head -50
echo === find logger templates ===
find /usr/www /offload -name "logger.conf*" 2>/dev/null | head -20
'
