#!/usr/bin/env bash
# No-domain setup: self-signed TLS certificate for the EC2 public IP + Backstage Nginx site.
# Usage: sudo deploy/scripts/enable-nginx-selfsigned.sh 13.201.19.126
# Re-run with the new IP if the instance's public IP changes (use an Elastic IP to avoid that).
set -euo pipefail
IP="${1:?public IP required}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DIR=/etc/ssl/backstage

install -d -m 0755 "$DIR" /var/www/certbot
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 365 \
  -subj "/CN=${IP}" -addext "subjectAltName=IP:${IP}" \
  -keyout "$DIR/privkey.pem" -out "$DIR/fullchain.pem" 2>/dev/null
chmod 0600 "$DIR/privkey.pem"; chmod 0644 "$DIR/fullchain.pem"

sed -e "s|__DOMAIN__|${IP}|g" \
    -e "s|__SSL_CERT__|${DIR}/fullchain.pem|" \
    -e "s|__SSL_KEY__|${DIR}/privkey.pem|" \
    "${HERE}/nginx/backstage.conf.template" > /etc/nginx/sites-available/backstage
ln -sfn /etc/nginx/sites-available/backstage /etc/nginx/sites-enabled/backstage
nginx -t && systemctl reload nginx
openssl x509 -in "$DIR/fullchain.pem" -noout -subject -ext subjectAltName -enddate
echo "Enabled https://${IP} (self-signed)"
