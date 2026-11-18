#!/bin/sh
# Back up site config and persistent runtime data (not the container logs).
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"

[ -f config/config.json ] || { echo "ERROR: config/config.json not found" >&2; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p backups
OUT="backups/fm-dx-config-$STAMP.tgz"

set --
[ -f config/config.json ] && set -- "$@" config/config.json
for dir in data/plugins_configs data/scanner data/rds; do
    [ -d "$dir" ] && set -- "$@" "$dir"
done
[ -f data/serverlog.txt ] && set -- "$@" data/serverlog.txt

tar czf "$OUT" "$@"
echo "backup written: $OUT"
