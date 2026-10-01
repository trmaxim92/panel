#!/usr/bin/env bash
# Clean MikoPBX install on a fresh Ubuntu/Debian server
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Installing Docker (official repo)..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi
if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker compose version

echo "==> Creating www-user and data dirs..."
if ! id www-user &>/dev/null; then
  adduser --disabled-password --gecos "" www-user
fi
mkdir -p /var/spool/mikopbx/cf /var/spool/mikopbx/storage
chown -R www-user:www-user /var/spool/mikopbx/

echo "==> Opening firewall ports (ufw if present)..."
if command -v ufw &>/dev/null; then
  ufw allow 22/tcp   || true
  ufw allow 23/tcp   || true
  ufw allow 80/tcp   || true
  ufw allow 443/tcp  || true
  ufw allow 5060/tcp || true
  ufw allow 5060/udp || true
  ufw allow 5061/tcp || true
  ufw allow 10000:10800/udp || true
  ufw allow 8088/tcp || true
  ufw allow 8089/tcp || true
  ufw --force enable || true
fi

export ID_WWW_USER="$(id -u www-user)"
export ID_WWW_GROUP="$(id -g www-user)"
# Strong default if not set outside
export WEB_ADMIN_PASSWORD="${WEB_ADMIN_PASSWORD:-ChangeMeNow}"

echo "==> Pulling and starting MikoPBX..."
docker compose pull
docker compose up -d

echo "==> Waiting for services..."
sleep 15
docker ps --filter name=mikopbx
echo
docker logs mikopbx 2>&1 | tail -n 40 || true

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "=============================================="
echo " MikoPBX started"
echo " Web:      https://${IP:-YOUR_SERVER_IP}"
echo " Login:    admin"
echo " Password: ${WEB_ADMIN_PASSWORD}"
echo " Data:     /var/spool/mikopbx/{cf,storage}"
echo "=============================================="
echo "Next: change admin password, set public IP/NAT,"
echo "      add trunk, create extensions, test call."
