#!/usr/bin/env bash
# Health of the Backstage stack: Nginx, Backstage (official root health endpoints), PostgreSQL.
# Usage: deploy/scripts/healthcheck.sh [--insecure] [https://your-domain-or-ip]   exit 0 = all healthy
#   --insecure  skip TLS verification (self-signed certificate, no-domain setup)
set -uo pipefail
TLS_OPT=()
[[ "${1:-}" == --insecure ]] && { TLS_OPT=(-k); shift; }
PUBLIC_URL="${1:-}"
fail=0
ok()  { printf '  [OK]   %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; fail=1; }

echo "Nginx"
systemctl is-active --quiet nginx && ok "nginx.service active" || bad "nginx.service not active"
sudo nginx -t >/dev/null 2>&1 && ok "nginx -t config valid" || bad "nginx -t failed"

echo "Backstage"
state=$(docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{end}}' backstage 2>/dev/null)
[[ "$state" == running/healthy ]] && ok "container $state" || bad "container ${state:-missing}"
for p in liveness readiness; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://127.0.0.1:7007/.backstage/health/v1/$p")
  [[ "$code" == 200 ]] && ok "$p 200" || bad "$p HTTP $code"
done

echo "PostgreSQL"
pg_isready -h 127.0.0.1 -p 5432 -q && ok "pg_isready 127.0.0.1:5432" || bad "PostgreSQL not accepting connections"

if [[ -n "$PUBLIC_URL" ]]; then
  echo "Public endpoint"
  code=$(curl -s "${TLS_OPT[@]}" -o /dev/null -w '%{http_code}' -m 10 "$PUBLIC_URL/.backstage/health/v1/readiness")
  [[ "$code" == 200 ]] && ok "$PUBLIC_URL readiness 200 via Nginx/TLS" || bad "$PUBLIC_URL readiness HTTP $code"
fi
exit $fail
