#!/usr/bin/env bash
set -euo pipefail

# setup.sh - Initialize the blue-green deployment
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

log "🔧 Setting up Blue-Green Deployment..."

# Make all scripts executable
chmod +x "$BASE_DIR"/*.sh

# Create initial active color file
echo "blue" > "$ROOT_DIR/.active_color"

# Create nginx conf directory if not exists
mkdir -p "$ROOT_DIR/nginx/conf.d"

# Start initial deployment
log "🚀 Starting initial deployment with blue..."
"$BASE_DIR/deploy.sh" blue

log "✅ Setup completed successfully!"
log "🎯 Run './scripts/health_check.sh' to verify the deployment"