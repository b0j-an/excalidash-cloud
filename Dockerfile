# Stage 1: Get prebuilt frontend assets from official ExcaliDash frontend
FROM zimengxiong/excalidash-frontend:latest AS frontend-assets

# Stage 2: Backend + Nginx
FROM zimengxiong/excalidash-backend:latest

USER root

# Install nginx and curl
RUN apk add --no-cache nginx curl && \
    mkdir -p /run/nginx /var/www/html /etc/nginx/http.d

# Copy frontend static files from Stage 1
COPY --from=frontend-assets /usr/share/nginx/html /var/www/html

# Copy unified nginx configuration template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Copy entrypoint script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Render injects PORT (default 10000)
EXPOSE 10000

ENTRYPOINT ["/start.sh"]
