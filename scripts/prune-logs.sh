#!/bin/sh
# Delete scanner logs older than DAYS (default 90).
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"

DAYS=${DAYS:-90}
[ -d data/logs ] || { echo "no data/logs yet"; exit 0; }

find data/logs -type f -mtime +"$DAYS" -print -delete
