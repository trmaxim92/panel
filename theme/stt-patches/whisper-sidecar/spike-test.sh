#!/bin/sh
set -e
SAMPLE=$(find /storage/usbdisk1/mikopbx/astspool/monitor -type f -name "*.webm" | head -1)
echo "sample=$SAMPLE"
OUT=/tmp/whisper-spike.wav
if [ ! -f "$OUT" ]; then
  ffmpeg -y -i "$SAMPLE" -ac 1 -ar 16000 "$OUT"
fi
ls -la "$OUT"
PAYLOAD=$(printf '{"path":"%s","language":"ru","model":"tiny"}' "$OUT")
echo "$PAYLOAD" > /tmp/whisper-job.json
RESP=$(wget -q -O - --header="Content-Type: application/json" --post-file=/tmp/whisper-job.json http://127.0.0.1:8791/jobs)
echo "submit=$RESP"
JOB=$(echo "$RESP" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
echo "job=$JOB"
i=0
while [ "$i" -lt 60 ]; do
  i=$((i + 1))
  ST=$(wget -q -O - "http://127.0.0.1:8791/jobs/$JOB")
  STATUS=$(echo "$ST" | sed -n 's/.*"status": *"\([^"]*\)".*/\1/p')
  echo "t=${i} status=$STATUS"
  case "$STATUS" in
    completed|failed)
      echo "$ST" | head -c 1200
      echo
      break
      ;;
  esac
  sleep 2
done
free -m | head -2
