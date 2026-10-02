# MikoPBX overlay (snapshot from production)

Снимок кастомных файлов с VPS `mikopbx` от **2026-10-02**.

Дерево повторяет пути в контейнере:

```
overlay/usr/www/...
```

## Что внутри

- История вызовов (CDR UI + `GetListAction` с фильтрами/отделом)
- Раздел «Записи звонков»
- `AssetProvider`, `Elements` (меню)
- `custom.css` (тема + патчи)
- Снимок маршрутов/очередей в `config/routing-snapshot.txt` (без SIP-паролей)

## Локальная работа

1. Править файлы здесь или в `theme/cdr-patches/` (удобные исходники патчей).
2. Проверка локально: `.\dev-up.ps1` (если нужен полный Miko в Docker).
3. Выкладка на VPS после `git push`:

```bash
cd /opt/skyscale-pbx   # или путь клонирования
git pull
sudo bash deploy-overlay.sh
```

## Обновить снимок с прода

```powershell
.\sync-from-vps.ps1
```
