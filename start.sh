#!/bin/sh
set -e

# Capture Render's incoming port (default 10000) for Nginx
RENDER_PORT="${PORT:-10000}"

echo "[STARTUP] Configuring Nginx to listen on public port ${RENDER_PORT}..."
mkdir -p /run/nginx /etc/nginx/http.d
sed "s/__PORT__/${RENDER_PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/http.d/default.conf

# Start Nginx in background
echo "[STARTUP] Starting Nginx daemon..."
nginx

# Set internal port for Node.js backend
export PORT=8000
export TRUST_PROXY=1

echo "[STARTUP] Launching ExcaliDash backend on internal port 8000..."
cd /app
exec ./docker-entrypoint.sh
