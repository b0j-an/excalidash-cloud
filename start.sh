#!/bin/sh
set -e

# Capture Render's incoming port (default 10000) for Nginx
RENDER_PORT="${PORT:-10000}"

echo "[STARTUP] Configuring Nginx to listen on public port ${RENDER_PORT}..."
mkdir -p /run/nginx /etc/nginx/http.d /etc/nginx/conf.d
rm -f /etc/nginx/http.d/*.conf /etc/nginx/conf.d/*.conf
sed "s/__PORT__/${RENDER_PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/http.d/default.conf

# Test Nginx configuration
echo "[STARTUP] Testing Nginx configuration..."
nginx -t

# Ensure frontend assets have native trackpad panning enabled
if [ -f /patch-canvas-zoom.js ]; then
    node /patch-canvas-zoom.js /var/www/html/assets || true
fi

# Set environment variables for Node.js backend
export PORT=8000
export TRUST_PROXY=true
export DATABASE_PROVIDER="${DATABASE_PROVIDER:-sqlite}"
export DATABASE_URL="${DATABASE_URL:-file:/app/prisma/dev.db}"
export NODE_ENV="${NODE_ENV:-production}"

# Variables to store child PIDs
BACKEND_PID=""
NGINX_PID=""

# Graceful shutdown handler
cleanup() {
    echo "[SHUTDOWN] Received termination signal, stopping processes..."
    [ -n "$BACKEND_PID" ] && kill -TERM "$BACKEND_PID" 2>/dev/null || true
    [ -n "$NGINX_PID" ] && kill -TERM "$NGINX_PID" 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT

check_backend_health() {
    if command -v curl >/dev/null 2>&1; then
        curl -s -f http://127.0.0.1:8000/health >/dev/null 2>&1
    else
        wget -q -O /dev/null http://127.0.0.1:8000/health 2>/dev/null
    fi
}

echo "[STARTUP] Starting ExcaliDash backend on internal port 8000..."
cd /app
./docker-entrypoint.sh &
BACKEND_PID=$!

echo "[STARTUP] Waiting for backend to become ready on port 8000..."
max_retries=180
count=0
ready=0

while [ $count -lt $max_retries ]; do
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "[ERROR] Backend process died during startup!"
        exit 1
    fi

    if check_backend_health; then
        ready=1
        break
    fi

    count=$((count + 1))
    if [ $((count % 5)) -eq 0 ]; then
        echo "[STARTUP] Waiting for backend to become ready... (${count}/${max_retries}s)"
    fi
    sleep 1
done

if [ $ready -ne 1 ]; then
    echo "[ERROR] Timed out waiting for backend to become ready after ${max_retries}s!"
    [ -n "$BACKEND_PID" ] && kill -TERM "$BACKEND_PID" 2>/dev/null || true
    exit 1
fi

echo "[STARTUP] Backend is healthy! Starting Nginx on public port ${RENDER_PORT}..."
nginx -g "daemon off;" &
NGINX_PID=$!

sleep 1
if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    echo "[ERROR] Nginx failed to start!"
    [ -n "$BACKEND_PID" ] && kill -TERM "$BACKEND_PID" 2>/dev/null || true
    exit 1
fi

echo "[STARTUP] All services running. Monitoring processes..."
while kill -0 "$BACKEND_PID" 2>/dev/null && kill -0 "$NGINX_PID" 2>/dev/null; do
    sleep 2
done

echo "[ERROR] One of the services stopped unexpectedly!"
[ -n "$BACKEND_PID" ] && kill -TERM "$BACKEND_PID" 2>/dev/null || true
[ -n "$NGINX_PID" ] && kill -TERM "$NGINX_PID" 2>/dev/null || true
exit 1

