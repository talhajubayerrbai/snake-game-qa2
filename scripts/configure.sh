#!/usr/bin/env bash
# configure.sh — runs on the EC2 instance via SSH after provision
# Usage: configure.sh <TARBALL_PATH>
set -euo pipefail

TARBALL="${1:?TARBALL_PATH required}"
APP_DIR="/opt/snake-game-qa2"

echo "==> Installing Node.js 20"
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

echo "==> Installing PM2"
sudo npm install -g pm2

echo "==> Extracting artifact from ${TARBALL}"
sudo rm -rf "${APP_DIR}"
sudo mkdir -p "${APP_DIR}"
sudo tar -xzf "${TARBALL}" -C "${APP_DIR}"
sudo rm -f "${TARBALL}"

echo "==> Installing production dependencies"
cd "${APP_DIR}"
sudo npm ci --omit=dev

echo "==> Configuring Nginx reverse proxy"
cat <<'NGINX' | sudo tee /etc/nginx/conf.d/snake-game.conf
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}
NGINX

sudo nginx -t
sudo systemctl reload nginx || sudo systemctl start nginx

echo "==> Starting app with PM2"
cd "${APP_DIR}"
sudo pm2 delete snake-game-qa2 2>/dev/null || true
sudo pm2 start server.js --name snake-game-qa2 --update-env
sudo pm2 save
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root || true

echo "==> Configure complete — app running on port 3000, Nginx proxying port 80"
