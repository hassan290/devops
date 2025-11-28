#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"
NGINX_CONF="$ROOT_DIR/nginx/conf.d/nginx.conf"
ACTIVE_FILE="$ROOT_DIR/.active_color"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

# Determine current active color
CURRENT=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")

if [ "$CURRENT" = "blue" ]; then
    NEW="green"
    NEW_CONTAINER="app_green"
    NEW_SERVER="app_green:5000"
    BACKUP_SERVER="app_blue:5000"
    log "🔄 Switching from BLUE to GREEN"
else
    NEW="blue"
    NEW_CONTAINER="app_blue"
    NEW_SERVER="app_blue:5000"
    BACKUP_SERVER="app_green:5000"
    log "🔄 Switching from GREEN to BLUE"
fi

# Wait for the new server to be healthy
log "⏳ Waiting for $NEW server to be healthy..."
MAX_ATTEMPTS=30
attempt=1
until [ "$(docker inspect --format='{{.State.Health.Status}}' ${NEW_CONTAINER})" = "healthy" ]; do
    if [ $attempt -gt $MAX_ATTEMPTS ]; then
        log "❌ $NEW failed to become healthy. Aborting switch."
        exit 1
    fi
    log "Attempt $attempt/$MAX_ATTEMPTS - $NEW status: $(docker inspect --format='{{.State.Health.Status}}' ${NEW_CONTAINER})"
    sleep 5
    ((attempt++))
done
log "✅ $NEW is healthy!"

# Update nginx config
log "📝 Updating nginx configuration..."
cat > "$NGINX_CONF" << EOF
upstream webcalc_upstream {
    server $NEW_SERVER max_fails=1 fail_timeout=5s;
    server $BACKUP_SERVER backup;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://webcalc_upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
}
EOF

# Reload nginx
log "🔄 Reloading nginx..."
docker compose exec nginx nginx -s reload

# Update active color
echo "$NEW" > "$ACTIVE_FILE"

log "✅ Traffic switched to $NEW successfully!"