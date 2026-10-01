# СкайСкейл / MikoPBX

Локальная разработка темы MikoPBX и выкладка на VPS через git.

## Локально (Windows + Docker Desktop)

```powershell
.\dev-up.ps1
```

- UI: https://127.0.0.1:18443  
- Логин: `admin` / `admin`  
- Тема: `theme/skyscale-theme.css`  
- Логотип: `theme/brand/`  

После правок CSS/лого:

```powershell
.\dev-apply-theme.ps1
```

## VPS (Linux)

Клон / обновление:

```bash
git clone git@github.com:trmaxim92/panel.git /opt/skayscale-pbx
# или
cd /opt/skayscale-pbx && git pull
```

Первичная установка Miko (один раз):

```bash
cd /opt/skayscale-pbx
sudo WEB_ADMIN_PASSWORD='StrongPass' bash install.sh
```

Применить тему и логотип на уже работающий контейнер `mikopbx`:

```bash
sudo bash deploy-theme.sh
```

## Состав

| Путь | Назначение |
|------|------------|
| `docker-compose.yml` | прод (host network) |
| `docker-compose.dev.yml` | локальная разработка |
| `theme/` | CSS + бренд |
| `install.sh` | чистая установка Docker Miko |
| `deploy-theme.sh` | git-friendly выкладка темы на VPS |
