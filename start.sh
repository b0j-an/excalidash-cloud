#!/bin/sh
set -e

# Capture Render's incoming port (default 10000) for Nginx
RENDER_PORT="${PORT:-10000}"

echo "[STARTUP] Configuring Nginx to listen on public port ${RENDER_PORT}..."
mkdir -p /run/nginx /etc/nginx/http.d
sed "s/__PORT__/${RENDER_PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/http.d/default.conf

# Set internal port for Node.js backend
export PORT=8000
export TRUST_PROXY=1

echo "[STARTUP] Starting ExcaliDash backend on internal port 8000..."
cd /app
./docker-entrypoint.sh &
BACKEND_PID=$!

echo "[STARTUP] Waiting for backend to become ready on port 8000..."
max_retries=120
count=0
until wget -q --spider http://127.0.0.1:8000/health 2>/dev/null; do
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo "[ERROR] Backend died during startup!"
        exit 1
    fi
    count=$((count + 1))
    if [ $count -ge $max_retries ]; then
        echo "[ERROR] Timed out waiting for backend to become ready!"
        exit 1
    fi
    sleep 0.5
done

echo "[STARTUP] Backend is healthy! Starting Nginx on public port ${RENDER_PORT}..."
nginx

# Trap termination signals and forward to children
trap "echo '[SHUTDOWN] Received signal, stopping processes...'; kill -TERM $BACKEND_PID $(cat /run/nginx.pid 2>/dev/null) 2>/dev/null; exit 0" TERM INT

echo "[STARTUP] All services running. Monitoring processes..."
while kill -0 $BACKEND_PID 2>/dev/null && kill -0 $(cat /run/nginx.pid 2>/dev/null) 2>/dev/null; do
    sleep 2
done

echo "[ERROR] One of the services stopped unexpectedly!"
kill -TERM $BACKEND_PID $(cat /run/nginx.pid 2>/dev/null) 2>/dev/null || true
exit 1

