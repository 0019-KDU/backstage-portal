#!/usr/bin/env bash
# Obtain a Let's Encrypt certificate for DOMAIN and enable the Backstage Nginx site.
# Usage: sudo deploy/scripts/enable-nginx-site.sh backstage.example.com admin@example.com
set -euo pipefail
DOMAIN="${1:?domain required}"
EMAIL="${2:?email for Let's Encrypt expiry notices required}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

install -d -m 0755 /var/www/certbot

# 1) Temporary HTTP-only site so certbot's HTTP-01 webroot challenge can be served.
cat > /etc/nginx/sites-available/backstage <<CONF
server {
    listen 80; listen [::]:80;
    server_name ${DOMAIN};
    location ^~ /.well-known/acme-challenge/ { root /var/www/certbot; default_type text/plain; }
    location / { return 404; }
}
CONF
ln -sfn /etc/nginx/sites-available/backstage /etc/nginx/sites-enabled/backstage
nginx -t && systemctl reload nginx

# 2) Certificate (webroot, so certbot never rewrites our Nginx config).
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  certbot certonly --webroot -w /var/www/certbot -d "${DOMAIN}" \
    --email "${EMAIL}" --agree-tos --no-eff-email --non-interactive
fi

# 3) Full TLS reverse-proxy site.
sed -e "s|__DOMAIN__|${DOMAIN}|g" \
    -e "s|__SSL_CERT__|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|" \
    -e "s|__SSL_KEY__|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|" \
    "${HERE}/nginx/backstage.conf.template" > /etc/nginx/sites-available/backstage
nginx -t && systemctl reload nginx

# 4) Reload Nginx after every renewal so the new cert is served.
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

echo "Enabled https://${DOMAIN}"
