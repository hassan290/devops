#!/usr/bin/env bash
set -euo pipefail

# rollback.sh
# Basic rollback: if a .active_color.previous exists, switch to it.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"
ACTIVE_FILE="$ROOT_DIR/.active_color"
PREV_FILE="$ROOT_DIR/.active_color.previous"
UPSTREAM_ACTIVE="$ROOT_DIR/nginx/conf.d/nginx.conf"
UPSTREAM_BLUE="$ROOT_DIR/nginx/conf.d/upstream_blue.conf"
UPSTREAM_GREEN="$ROOT_DIR/nginx/conf.d/upstream_green.conf"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

log "🔄 Starting rollback process..."

if [ -f "$PREV_FILE" ]; then
  PREV=$(cat "$PREV_FILE")
  log "Found previous active color: $PREV"
  
  if [ "$PREV" = "blue" ]; then
    SRC="$UPSTREAM_BLUE"
  else
    SRC="$UPSTREAM_GREEN"
  fi
  
  if [ ! -f "$SRC" ]; then
    log "Upstream template not found: $SRC"
    exit 1
  fi
  
  # Backup current config
  if [ -f "$UPSTREAM_ACTIVE" ]; then
    cp "$UPSTREAM_ACTIVE" "${UPSTREAM_ACTIVE}.bak.rollback.$(date +%s)"
  fi
  
  # Atomic replace
  tmp="$(mktemp)"
  cp "$SRC" "$tmp"
  mv "$tmp" "$UPSTREAM_ACTIVE"
  
  # Reload nginx
  log "🔄 Reloading nginx..."
  docker compose exec -T nginx nginx -s reload
  
  # Update active color
  echo "$PREV" > "$ACTIVE_FILE"
  
  log "Rollback complete! Active color: $PREV"
  log "Application URL: http://localhost:${NGINX_PORT:-80}"
  
else
  log "No previous active color recorded (.active_color.previous not found)"
  log "Unable to perform automatic rollback."
  log "You can manually run: ./scripts/switch_traffic.sh"
  exit 1
fi