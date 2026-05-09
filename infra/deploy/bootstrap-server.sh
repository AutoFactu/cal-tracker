#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="/srv/cal-tracker/deploy"
ENV_DIR="/srv/cal-tracker/env"
STATE_DIR="/srv/cal-tracker/state"

install -d -m 0755 "$DEPLOY_DIR" "$DEPLOY_DIR/postgres" "$DEPLOY_DIR/nginx" "$ENV_DIR" "$STATE_DIR" /etc/nginx/snippets
install -d -m 0755 /var/www/bettercalories.app/html

cp compose.yml "$DEPLOY_DIR/compose.yml"
cp postgres/init.sql "$DEPLOY_DIR/postgres/init.sql"
cp deploy.sh "$DEPLOY_DIR/deploy.sh"
cp backup-postgres-schema.sh "$DEPLOY_DIR/backup-postgres-schema.sh"
chmod 755 "$DEPLOY_DIR/deploy.sh" "$DEPLOY_DIR/backup-postgres-schema.sh"
cp nginx/proxy-common.conf /etc/nginx/snippets/cal-tracker-proxy-common.conf

if [[ ! -f /etc/letsencrypt/live/api.bettercalories.app/fullchain.pem ]]; then
  cat > /etc/nginx/sites-available/api.bettercalories.app <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name api.bettercalories.app dev-api.bettercalories.app;

    root /var/www/bettercalories.app/html;

    location /.well-known/acme-challenge/ {
        try_files $uri =404;
    }

    location / {
        return 200 "cal-tracker api bootstrap\n";
    }
}
EOF
  ln -sfn /etc/nginx/sites-available/api.bettercalories.app /etc/nginx/sites-enabled/api.bettercalories.app
  nginx -t
  systemctl reload nginx
  certbot certonly --webroot -w /var/www/bettercalories.app/html \
    -d api.bettercalories.app \
    -d dev-api.bettercalories.app \
    --agree-tos \
    --register-unsafely-without-email \
    --non-interactive
fi

cp nginx/api.bettercalories.app.conf /etc/nginx/sites-available/api.bettercalories.app
ln -sfn /etc/nginx/sites-available/api.bettercalories.app /etc/nginx/sites-enabled/api.bettercalories.app

cat > /etc/nginx/snippets/cal-tracker-dev-proxy.conf <<'EOF'
include /etc/nginx/snippets/cal-tracker-proxy-common.conf;
proxy_pass http://127.0.0.1:3101;
EOF

cat > /etc/nginx/snippets/cal-tracker-pro-proxy.conf <<'EOF'
include /etc/nginx/snippets/cal-tracker-proxy-common.conf;
proxy_pass http://127.0.0.1:3201;
EOF

touch "$STATE_DIR/dev.active" "$STATE_DIR/pro.active"

if [[ ! -f "$ENV_DIR/deploy.env" ]]; then
  cat > "$ENV_DIR/deploy.env" <<'EOF'
POSTGRES_PASSWORD=replace-with-strong-postgres-password
BACKEND_IMAGE=ghcr.io/autofactu/cal-tracker-backend:bootstrap
EOF
  chmod 600 "$ENV_DIR/deploy.env"
fi

if [[ ! -f "$ENV_DIR/dev.env" ]]; then
  cat > "$ENV_DIR/dev.env" <<'EOF'
APP_BASE_URL=https://dev-api.bettercalories.app
CORS_ALLOWED_ORIGINS=https://dev-api.bettercalories.app
JWT_ACCESS_SECRET=replace-with-dev-secret-at-least-32-characters
SESSION_TOKEN_PEPPER=replace-with-dev-pepper-at-least-32-characters
OPENROUTER_API_KEY=replace-with-openrouter-key
OPENROUTER_MODEL=deepseek/deepseek-v4-flash
STT_API_KEY=replace-with-groq-key
STT_MODEL=whisper-large-v3-turbo
STT_BASE_URL=https://api.groq.com/openai/v1
EMBEDDING_PROVIDER=local
EMBEDDING_MODEL=bge-m3
EMBEDDING_DIMENSIONS=1024
TRUSTED_AUTO_COMMIT_THRESHOLD=0.92
EOF
  chmod 600 "$ENV_DIR/dev.env"
fi

if [[ ! -f "$ENV_DIR/pro.env" ]]; then
  cp "$ENV_DIR/dev.env" "$ENV_DIR/pro.env"
  sed -i 's#https://dev-api.bettercalories.app#https://api.bettercalories.app#g' "$ENV_DIR/pro.env"
  chmod 600 "$ENV_DIR/pro.env"
fi

nginx -t
systemctl reload nginx

echo "Bootstrap files installed. Fill /srv/cal-tracker/env/*.env before first deploy."
