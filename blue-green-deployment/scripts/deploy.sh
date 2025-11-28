#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"
COMPOSE_CMD="docker compose"
NGINX_SERVICE="nginx"
BLUE_SERVICE="app_blue"
GREEN_SERVICE="app_green"
UPSTREAM_ACTIVE="$ROOT_DIR/nginx/conf.d/nginx.conf"
UPSTREAM_BLUE="$ROOT_DIR/nginx/conf.d/upstream_blue.conf"
UPSTREAM_GREEN="$ROOT_DIR/nginx/conf.d/upstream_green.conf"
ACTIVE_FILE="$ROOT_DIR/.active_color"
PREV_FILE="$ROOT_DIR/.active_color.previous"
HEALTH_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"
POLL_INTERVAL="${HEALTH_CHECK_POLL:-5}"

# Validate arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <blue|green>"
  exit 2
fi

TARGET_COLOR="$1"
if [ "$TARGET_COLOR" != "blue" ] && [ "$TARGET_COLOR" != "green" ]; then
  echo "Invalid target color: $TARGET_COLOR"
  exit 2
fi

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

TARGET_SERVICE=$([ "$TARGET_COLOR" = "blue" ] && echo "$BLUE_SERVICE" || echo "$GREEN_SERVICE")
TARGET_UPSTREAM=$([ "$TARGET_COLOR" = "blue" ] && echo "$UPSTREAM_BLUE" || echo "$UPSTREAM_GREEN")
OTHER_SERVICE=$([ "$TARGET_COLOR" = "blue" ] && echo "$GREEN_SERVICE" || echo "$BLUE_SERVICE")

log "Starting deployment: $TARGET_COLOR (service: $TARGET_SERVICE)"

# Record previous color for rollback
if [ -f "$ACTIVE_FILE" ]; then
    cp "$ACTIVE_FILE" "$PREV_FILE"
    log "Previous color saved: $(cat "$PREV_FILE")"
fi

# 1) Pull new image
log "⬇️  Pulling image for $TARGET_SERVICE..."
$COMPOSE_CMD pull "$TARGET_SERVICE"

# 2) Start target service
log "Starting $TARGET_SERVICE..."
$COMPOSE_CMD up -d --no-deps "$TARGET_SERVICE"

# 3) Health check with detailed logging
log "Waiting up to ${HEALTH_TIMEOUT}s for health check..."
elapsed=0
CID=$($COMPOSE_CMD ps -q "$TARGET_SERVICE")

if [ -z "$CID" ]; then
  log "Could not find container for $TARGET_SERVICE"
  exit 3
fi

while true; do
  status=$(docker inspect --format='{{.State.Health.Status}}' "$CID" 2>/dev/null || echo "no_health")
  log "Health status: $status (elapsed: ${elapsed}s)"
  
  if [ "$status" = "healthy" ]; then
    log "$TARGET_SERVICE is healthy!"
    break
  fi
  
  if [ "$elapsed" -ge "$HEALTH_TIMEOUT" ]; then
    log "Health check timeout after ${elapsed}s"
    log "Performing rollback: stopping $TARGET_SERVICE"
    $COMPOSE_CMD stop "$TARGET_SERVICE" || true
    exit 4
  fi
  
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

# 4) Atomic switch of nginx config
log "Switching nginx upstream to $TARGET_COLOR..."
if [ ! -f "$TARGET_UPSTREAM" ]; then
  log "Upstream template not found: $TARGET_UPSTREAM"
  exit 5
fi

# Backup current config
if [ -f "$UPSTREAM_ACTIVE" ]; then
  cp "$UPSTREAM_ACTIVE" "${UPSTREAM_ACTIVE}.bak.$(date +%s)"
fi

# Atomic replace
tmpfile="$(mktemp)"
cp "$TARGET_UPSTREAM" "$tmpfile"
mv "$tmpfile" "$UPSTREAM_ACTIVE"

# 5) Reload nginx
log "Reloading nginx..."
$COMPOSE_CMD exec -T "$NGINX_SERVICE" nginx -s reload

# 6) Update active color
echo "$TARGET_COLOR" > "$ACTIVE_FILE"

# 7) Stop old service (optional - comment if you want both running)
log "Stopping previous service: $OTHER_SERVICE"
$COMPOSE_CMD stop "$OTHER_SERVICE" 2>/dev/null || true

# 8) Cleanup
log "Cleaning up old containers..."
docker system prune -f --filter "until=24h" 2>/dev/null || true

log "Deployment completed successfully! Active color: $TARGET_COLOR"
log "Application URL: http://localhost:${NGINX_PORT:-80}"