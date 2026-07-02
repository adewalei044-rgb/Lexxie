#!/usr/bin/env bash
# One-shot setup for the Lexxie TradingView -> Bybit webhook relay.
# Run as root on a fresh Ubuntu 22.04 VPS:
#   curl -fsSL https://raw.githubusercontent.com/adewalei044-rgb/lexxie/<branch>/webhook-relay/install.sh | bash -s -- <branch>
# or copy this file over and run: bash install.sh <branch>
set -euo pipefail

REPO_URL="https://github.com/adewalei044-rgb/lexxie.git"
BRANCH="${1:-main}"
APP_DIR="/opt/lexxie-relay"
SVC_USER="lexxie"

echo "==> Installing system packages"
apt-get update -y
apt-get install -y curl git nginx

echo "==> Installing Node.js 20.x"
if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "==> Creating service user"
if ! id "$SVC_USER" >/dev/null 2>&1; then
    useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SVC_USER"
fi

echo "==> Fetching relay code (branch: $BRANCH)"
TMP_DIR=$(mktemp -d)
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR"
mkdir -p "$APP_DIR"
cp -r "$TMP_DIR"/webhook-relay/* "$APP_DIR"/
rm -rf "$TMP_DIR"

echo "==> Installing npm dependencies"
cd "$APP_DIR"
npm install --omit=dev

if [ ! -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/.env.example" "$APP_DIR/.env"
    echo "==> Created $APP_DIR/.env - YOU MUST EDIT THIS before the relay will work:"
    echo "        nano $APP_DIR/.env"
fi

chown -R "$SVC_USER":"$SVC_USER" "$APP_DIR"

echo "==> Installing systemd service"
cp "$APP_DIR/lexxie-relay.service" /etc/systemd/system/lexxie-relay.service
systemctl daemon-reload
systemctl enable lexxie-relay

echo "==> Configuring firewall (SSH + HTTP/HTTPS only)"
ufw allow 22/tcp || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable || true

cat <<'EOF'

==================================================================
Next steps (do these before starting the service):

1. Edit /opt/lexxie-relay/.env and fill in:
   - WEBHOOK_SECRET   (generate with: openssl rand -hex 24)
   - BYBIT_API_KEY / BYBIT_API_SECRET (Trade permission only, no withdraw)
   - Leave BYBIT_TESTNET=true until you've verified everything works

2. Start the relay:
     systemctl start lexxie-relay
     systemctl status lexxie-relay
     journalctl -u lexxie-relay -f      (live logs)

3. (Optional but recommended) Put it behind HTTPS:
     cp /opt/lexxie-relay/nginx.conf.template /etc/nginx/sites-available/lexxie-relay
     nano /etc/nginx/sites-available/lexxie-relay      (set your domain)
     ln -s /etc/nginx/sites-available/lexxie-relay /etc/nginx/sites-enabled/
     nginx -t && systemctl reload nginx
     apt-get install -y certbot python3-certbot-nginx
     certbot --nginx -d YOUR_DOMAIN

4. In TradingView, set your Alert's Webhook URL to:
     https://YOUR_DOMAIN/hook/<your WEBHOOK_SECRET>
   (or http://VPS_IP:3000/hook/<secret> if skipping HTTPS - not recommended
   since your webhook secret would travel unencrypted)

5. Test with BYBIT_TESTNET=true and tiny size before ever flipping to live.
==================================================================
EOF
