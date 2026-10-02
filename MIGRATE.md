# Перенос MikoPBX на другой сервер

Пакет: `mikopbx-migrate.tgz` (~124 МБ)  
Распаковано: `migrate/mikopbx-migrate/`

## Состав

| Файл | Назначение |
|------|------------|
| `data/cf.tgz` | Конфиг АТС `/cf` (БД, настройки, **пароли SIP/админки**) |
| `data/storage-nologs.tgz` | Медиа, модули, CDR (~109 МБ). **Без** логов (~14 ГБ) |
| `data/usr-www-full.tgz` | Полный код `/usr/www` (кастомный UI/API) |
| `host/docker-compose.yml` | Запуск контейнера (host network) |
| `host/docker-inspect.json` | Как было на старом VPS |

Дополнительно в репозитории:
- `full-code/` / `mikopbx-full-code.tgz` — только код www
- `overlay/` — тонкий слой наших патчей

## Восстановление на новом сервере

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sh

# 2. Распаковать миграционный архив
tar -xzf mikopbx-migrate.tgz
cd mikopbx-migrate

# 3. Данные
mkdir -p /var/spool/mikopbx
tar -C /var/spool/mikopbx -xzf data/cf.tgz
mkdir -p /var/spool/mikopbx/storage
tar -C /var/spool/mikopbx/storage -xzf data/storage-nologs.tgz

# 4. Запуск
cd host
docker compose pull
docker compose up -d

# 5. Кастомный www (архив из корня /usr/www)
docker cp ../data/usr-www-full.tgz mikopbx:/tmp/
docker exec mikopbx sh -c '\
  tar -C /usr/www -xzf /tmp/usr-www-full.tgz && \
  mkdir -p /offload/rootfs/usr/www && \
  cp -a /usr/www/. /offload/rootfs/usr/www/ && \
  php -r "if(function_exists(\"opcache_reset\")) opcache_reset();"'
```

## После переноса обязательно

1. В панели MikoPBX указать **новый публичный IP** (NAT / external address).
2. В кабинете провайдера (Plusofon) разрешить **новый IP**.
3. Fail2Ban: whitelist офисных IP.
4. Проверить регистрацию транка и внутренние 204/205.
5. **Не публикуйте** `mikopbx-migrate.tgz` в открытый git — внутри секреты.

Образ: `ghcr.io/mikopbx/mikopbx:latest`, network_mode: `host`,  
volume: `/var/spool/mikopbx/cf` → `/cf`, `/var/spool/mikopbx/storage` → `/storage`.
