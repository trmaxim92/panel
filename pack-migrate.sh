#!/bin/sh
set -e
OUT=/tmp/mikopbx-migrate
TGZ=/tmp/mikopbx-migrate.tgz
rm -rf "$OUT" "$TGZ"
mkdir -p "$OUT"

echo "== docker-compose / install =="
mkdir -p "$OUT/host"
cp -a /opt/skayscale-pbx/docker-compose.yml "$OUT/host/" 2>/dev/null || true
cp -a /opt/skyscale-pbx/docker-compose.dev.yml "$OUT/host/" 2>/dev/null || true
cp -a /opt/skyscale-pbx/install.sh "$OUT/host/" 2>/dev/null || true
cp -a /root/mikopbx/docker-compose.yml "$OUT/host/docker-compose.root.yml" 2>/dev/null || true
docker inspect mikopbx > "$OUT/host/docker-inspect.json"
docker inspect mikopbx --format '{{json .Config}}' > "$OUT/host/docker-config.json"

echo "== /cf (config DB — includes secrets) =="
mkdir -p "$OUT/data"
tar -C /var/spool/mikopbx -czf "$OUT/data/cf.tgz" cf

echo "== /storage without huge logs =="
# export storage excluding log (14G)
tar -C /var/spool/mikopbx/storage -czf "$OUT/data/storage-nologs.tgz" \
  --exclude='usbdisk1/mikopbx/log' \
  --exclude='usbdisk1/mikopbx/tmp' \
  .

echo "== custom www (from container) =="
docker exec mikopbx sh -c 'rm -rf /tmp/www-pack && mkdir -p /tmp/www-pack && tar -C /usr/www -czf /tmp/www-pack/usr-www-full.tgz --exclude=sites/admin-cabinet/assets/js/cache --exclude=cache --exclude=tmp --exclude="*.log" .'
docker cp mikopbx:/tmp/www-pack/usr-www-full.tgz "$OUT/data/usr-www-full.tgz"
docker exec mikopbx rm -rf /tmp/www-pack
mkdir -p "$OUT/overlay-notes"

echo "== versions =="
{
  echo "pulled_at=$(date -Iseconds)"
  echo "host=$(hostname)"
  echo "public_ip=159.194.248.186"
  docker inspect mikopbx --format 'image={{.Config.Image}}'
  docker exec mikopbx asterisk -rx "core show version" 2>/dev/null | head -1
  echo "cf_size=$(du -sh /var/spool/mikopbx/cf | awk '{print $1}')"
  echo "storage_total=$(du -sh /var/spool/mikopbx/storage | awk '{print $1}')"
  echo "storage_nologs_archive excludes usbdisk1/mikopbx/log"
  ls -lh "$OUT/data"
} | tee "$OUT/META.txt"

# migration readme
cat > "$OUT/MIGRATE.md" <<'EOF'
# Перенос MikoPBX на новый сервер

## Состав архива

| Файл | Назначение |
|------|------------|
| `data/cf.tgz` | Конфиг АТС (`/cf`) — БД, настройки, **секреты** |
| `data/storage-nologs.tgz` | Медиа, модули, CDR/бэкапы (**без** 14ГБ логов) |
| `data/usr-www-full.tgz` | Полный `/usr/www` (кастомный UI/API) |
| `host/docker-compose.yml` | Compose с host network |
| `host/docker-inspect.json` | Как контейнер был запущен |

## На новом сервере

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sh

# 2. Каталоги данных
mkdir -p /var/spool/mikopbx
cd /path/to/extracted/mikopbx-migrate
tar -C /var/spool/mikopbx -xzf data/cf.tgz
mkdir -p /var/spool/mikopbx/storage
tar -C /var/spool/mikopbx/storage -xzf data/storage-nologs.tgz

# 3. Запуск (из host/docker-compose.yml)
cd host
docker compose pull
docker compose up -d

# 4. Накатить кастомный www (после старта контейнера)
docker cp data/usr-www-full.tgz mikopbx:/tmp/
docker exec mikopbx sh -c 'mkdir -p /tmp/www && tar -C /tmp/www -xzf /tmp/usr-www-full.tgz && cp -a /tmp/www/usr/www/. /usr/www/ && cp -a /tmp/www/usr/www/. /offload/rootfs/usr/www/ 2>/dev/null; php -r "opcache_reset();"'

# 5. NAT / firewall: внешний IP нового сервера в MikoPBX
# Сеть → общие настройки, Fail2Ban whitelist, провайдер SIP
```

## Важно

- Образ: `ghcr.io/mikopbx/mikopbx:latest`
- Network mode: **host**
- Volumes: `/var/spool/mikopbx/cf` → `/cf`, `/var/spool/mikopbx/storage` → `/storage`
- Логи со старого сервера не переносились (были ~14 ГБ)
- После переноса смените публичный IP у провайдера (Plusofon) и в NAT АТС
EOF

cd /tmp
tar -czf "$TGZ" mikopbx-migrate
ls -lh "$TGZ"
du -sh "$OUT" "$OUT/data"/*
