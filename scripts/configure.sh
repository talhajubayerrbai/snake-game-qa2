#!/usr/bin/env bash
# configure.sh — runs on the EC2 instance via SSH after provision
# Usage: configure.sh <GIT_SHA> <GITHUB_TOKEN> <REPO>
set -euo pipefail

GIT_SHA="${1:?GIT_SHA required}"
GITHUB_TOKEN="${2:?GITHUB_TOKEN required}"
REPO="${3:?REPO required}"  # e.g. talhajubayerrbai/snake-game-qa2

APP_DIR="/opt/snake-game-qa2"
ARTIFACT_URL="https://api.github.com/repos/${REPO}/releases/tags/${GIT_SHA}"

echo "==> Installing Node.js 20"
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

echo "==> Installing PM2"
sudo npm install -g pm2

echo "==> Fetching release asset URL for tag ${GIT_SHA}"
ASSET_URL=$(curl -fsSL \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "${ARTIFACT_URL}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assets = data.get('assets', [])
for a in assets:
    if a['name'].endswith('.tar.gz'):
        print(a['browser_download_url'])
        break
")

if [ -z "${ASSET_URL}" ]; then
  echo "ERROR: no .tar.gz asset found in release ${GIT_SHA}" >&2
  exit 1
fi

echo "==> Downloading artifact from ${ASSET_URL}"
TMPFILE=$(mktemp /tmp/snake-XXXXXX.tar.gz)
curl -fsSL \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -L "${ASSET_URL}" \
  -o "${TMPFILE}"

echo "==> Extracting artifact"
sudo rm -rf "${APP_DIR}"
sudo mkdir -p "${APP_DIR}"
sudo tar -xzf "${TMPFILE}" -C "${APP_DIR}"
rm -f "${TMPFILE}"

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
sudo systemctl reload nginx

echo "==> Starting app with PM2"
cd "${APP_DIR}"
sudo pm2 delete snake-game-qa2 2>/dev/null || true
sudo pm2 start server.js --name snake-game-qa2 --update-env
sudo pm2 save
sudo pm2 startup systemd -u root --hp /root || true

echo "==> Configure complete — app running on port 3000, Nginx proxying port 80"
