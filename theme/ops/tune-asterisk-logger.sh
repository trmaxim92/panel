#!/bin/sh
# Apply Asterisk logger rotation limits inside mikopbx (best-effort).
set -eu
C=mikopbx
docker exec $C sh -c '
CONF=/etc/asterisk/logger.conf
[ -f "$CONF" ] || exit 0
if grep -q "^rotatesize" "$CONF" 2>/dev/null; then
  sed -i "s/^rotatesize.*/rotatesize = 50M/" "$CONF"
  sed -i "s/^rotatecount.*/rotatecount = 2/" "$CONF"
else
  # insert under [general]
  awk "
    BEGIN{done=0}
    /^\[general\]/{print; print \"rotatesize = 50M\"; print \"rotatecount = 2\"; done=1; next}
    {print}
  " "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
fi
# lower file verbose a bit (keep console as-is)
sed -i "s|verbose => verbose(3),dtmf,fax,warning|verbose => notice,warning,error|" "$CONF" 2>/dev/null || true
# Actually keep some verbose but not dtmf flood - use verbose(1)
sed -i "s|verbose => notice,warning,error|verbose => verbose(1),warning,error|" "$CONF" 2>/dev/null || true
echo "=== logger.conf now ==="
cat "$CONF"
asterisk -rx "logger reload" 2>/dev/null || true
'
