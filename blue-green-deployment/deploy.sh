#!/bin/bash
echo "Starting Blue-Green Deployment..."

# Load environment variables
source .env

# Start both containers if not running
docker compose up -d

# Wait until Green is healthy
echo "Waiting for Green container to be healthy..."
until [ $(docker inspect --format='{{.State.Health.Status}}' app_green) == "healthy" ]; do
  echo "Green not ready yet..."
  sleep 2
done

# Optional: Switch Traffic (if Nginx config is dynamic, or reload Nginx)
echo "Reloading Nginx to apply traffic switch..."
docker exec nginx nginx -s reload

echo "Deployment Completed!"
