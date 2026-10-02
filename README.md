# СкайСкейл / MikoPBX

Локальная разработка → тест в Docker → `git push` → выкладка на VPS.

## Быстрый цикл

```powershell
cd c:\call\mikopbx

# 1) поднять локальный Miko (один раз / при необходимости)
.\dev-up.ps1

# 2) править исходники здесь:
#    theme\cdr-patches\          — CDR / записи / API
#    theme\skyscale-theme.css    — тема
#    overlay\                    — полный деплой-слой (собирается скриптом)

# 3) накатить правки в локальный контейнер и проверить в браузере
.\dev-apply-overlay.ps1
# UI: https://127.0.0.1:18443   admin / admin

# 4) в git
git add -A
git commit -m "..."
git push

# 5) на VPS
# git pull && sudo bash deploy-overlay.sh
```

## Структура

| Путь | Назначение |
|------|------------|
| `theme/cdr-patches/` | **Редактируемые** исходники (JS, volt, GetListAction, записи) |
| `theme/skyscale-theme.css` | Тема |
| `overlay/` | Слой файлов для деплоя в `/usr/www` |
| `docker-compose.dev.yml` | Локальный Docker |
| `deploy-overlay.sh` | Выкладка overlay на прод-контейнер |
| `sync-patches-to-overlay.ps1` | Патчи → overlay |
| `sync-from-vps.ps1` | Стянуть overlay с прода (если нужно) |
| `mikopbx-migrate.tgz` | Архив переноса сервера (**секреты**, в git не пушится) |
| `MIGRATE.md` | Как переносить на новый VPS |

## Важно

- В git уходит код/оверлей/тема, **не** `mikopbx-migrate.tgz` (там пароли).
- Перед деплоем на VPS: `.\sync-patches-to-overlay.ps1`, затем commit/push и `deploy-overlay.sh` на сервере.
