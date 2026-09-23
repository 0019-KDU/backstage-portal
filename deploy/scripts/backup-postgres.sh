#!/usr/bin/env bash
# Non-destructive logical backup of the Backstage database (read-only pg_dump).
# Runs as the `postgres` OS user via peer auth; no password needed or stored.
# Never drops, truncates or deletes anything; old dumps are kept (prune manually).
set -euo pipefail
DB="${POSTGRES_DB:-backstage}"
DEST="${BACKUP_DIR:-/var/backups/backstage}"
ts=$(date -u +%Y%m%dT%H%M%SZ)
out="${DEST}/${DB}_${ts}.dump"
pg_dump --format=custom --no-owner --dbname="$DB" --file="${out}.partial"
pg_restore --list "${out}.partial" >/dev/null   # verify the archive is readable
mv "${out}.partial" "$out"
sha256sum "$out" > "${out}.sha256"
echo "backup ok: $out ($(du -h "$out" | cut -f1))"
