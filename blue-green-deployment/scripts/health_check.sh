#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"
ACTIVE_FILE="$ROOT_DIR/.active_color"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

echo "=== 🏥 System Health Check ==="
echo ""

# Show active color
if [ -f "$ACTIVE_FILE" ]; then
  echo "🎯 Active Color: $(cat "$ACTIVE_FILE")"
else
  echo "🎯 Active Color: unknown"
fi
echo ""

echo "=== 📊 Services Status ==="
docker compose ps

echo ""
echo "=== 🔍 Detailed Health Status ==="

for svc in app_blue app_green nginx; do
  cid=$(docker compose ps -q $svc 2>/dev/null || true)
  if [ -n "$cid" ]; then
    state=$(docker inspect --format='{{.State.Status}}' "$cid" 2>/dev/null || echo "unknown")
    health=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "no health")
    
    echo "📍 $svc:"
    echo "   State: $state"
    echo "   Health: $health"
    
    if [[ $svc == app_* ]]; then
      echo -n "   Endpoint Test: "
      if docker exec "$cid" curl -f -s http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ OK"
      else
        echo "❌ FAIL"
      fi
    fi
  else
    echo "📍 $svc: ❌ NOT RUNNING"
  fi
  echo ""
done

echo "=== 🌐 Nginx Routing Test ==="
if curl -f -s http://localhost/health > /dev/null; then
  echo "✅ Nginx Routing: HEALTHY"
else
  echo "❌ Nginx Routing: UNHEALTHY"
fi

echo ""
echo "=== ✅ Health Check Complete ==="