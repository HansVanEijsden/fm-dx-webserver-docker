#!/bin/sh
# Seed the persistent /data volume on first start and make sure it is writable.
set -eu

DATA=${DATA_DIR:-/data}

if ! mkdir -p "$DATA/scanner" "$DATA/rds" "$DATA/logs" "$DATA/plugins_configs" 2>/dev/null; then
    echo "ERROR: cannot create $DATA subdirectories." >&2
    echo "Create ./data on the host as the container user (uid 1000) before starting." >&2
    exit 1
fi
if ! touch "$DATA/.write-test" 2>/dev/null; then
    echo "ERROR: $DATA is not writable by uid 1000." >&2
    echo "Fix with: sudo chown -R 1000:1000 ./data  (or run scripts/bootstrap.sh)" >&2
    exit 1
fi
rm -f "$DATA/.write-test"

for f in blacklist.txt whitelist.txt blacklist_fmlist.txt blacklist_log.txt scanner_state.json; do
    if [ ! -e "$DATA/scanner/$f" ]; then
        if [ -f "/opt/fm-dx-webserver/defaults/scanner/$f" ]; then
            cp "/opt/fm-dx-webserver/defaults/scanner/$f" "$DATA/scanner/$f"
        elif [ "$f" = "scanner_state.json" ]; then
            echo '{}' > "$DATA/scanner/$f"
        else
            : > "$DATA/scanner/$f"
        fi
    fi
done

for f in rdsm_config.json rdsm_fmdx_cache.json rdsm_memory.json; do
    if [ ! -e "$DATA/rds/$f" ] && [ -f "/opt/fm-dx-webserver/defaults/rds/$f" ]; then
        cp "/opt/fm-dx-webserver/defaults/rds/$f" "$DATA/rds/$f"
    fi
done

[ -e "$DATA/serverlog.txt" ] || : > "$DATA/serverlog.txt"
