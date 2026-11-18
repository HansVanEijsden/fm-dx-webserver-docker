#!/bin/sh
# Copy site-specific customisations from an existing installation into this
# checkout. Everything written here is gitignored: never commit it.
# Usage: LEGACY_DIR=/home/hans/fm-dx-docker ./scripts/export-site.sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"

LEGACY_DIR=${LEGACY_DIR:-/home/hans/fm-dx-docker}
[ -d "$LEGACY_DIR" ] || { echo "ERROR: legacy dir not found: $LEGACY_DIR" >&2; exit 1; }

LEGACY_PLUGINS="$LEGACY_DIR/fm-dx-addons/plugins"
OVERLAY="site/overlay"
mkdir -p "$OVERLAY/plugins" data/plugins_configs data/scanner data/rds data/logs

copy_file() {
    src=$1
    dst=$2
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "copied $dst"
}

# Plugin files that are customised on this site (Bojcha visuals, local flags).
for rel in \
    MetricsMonitor/js/metricsmonitor-scope.js \
    MetricsMonitor/js/metricsmonitor-signal-analyzer.js \
    MetricsMonitor/js/metricsmonitor-signalmeter.js \
    ButtonPresets/pluginButtonPresets.js \
    RadioDNS/pluginRadioDNS.js \
    RadioDNS/pluginRadioDNS_server.js \
    SpectrumGraph/pluginSpectrumGraph.js \
    StationLogo/updateStationLogo.js \
    UIAddonPack/pluginUIAddonPack.js \
    ES-Alert/es-alert.js \
    LiveMap/livemap.js \
    ; do
    copy_file "$LEGACY_PLUGINS/$rel" "$OVERLAY/plugins/$rel"
done

# ButtonPresets carries the preset frequencies in its file; copy its wrapper
# as well so the reported version matches.
copy_file "$LEGACY_PLUGINS/ButtonPresets.js" "$OVERLAY/plugins/ButtonPresets.js"

# Site configuration (secrets) and plugin configuration.
copy_file "$LEGACY_DIR/config/config.json" "config/config.json"
chmod 600 config/config.json 2>/dev/null || true
if [ -d "$LEGACY_DIR/plugins_configs" ]; then
    cp -a "$LEGACY_DIR/plugins_configs/." data/plugins_configs/
    echo "copied data/plugins_configs"
fi

# Scanner lists/state and RDS runtime state.
for f in blacklist.txt whitelist.txt blacklist_fmlist.txt blacklist_log.txt scanner_state.json; do
    copy_file "$LEGACY_PLUGINS/Scanner/$f" "data/scanner/$f"
done
for f in rdsm_config.json rdsm_fmdx_cache.json rdsm_memory.json; do
    copy_file "$LEGACY_PLUGINS/RDS-AI-Decoder/$f" "data/rds/$f"
done

[ -e data/serverlog.txt ] || : > data/serverlog.txt
chmod -R u+rwX data 2>/dev/null || true

echo
echo "Site export complete. Files live in site/overlay, config/, and data/ and are gitignored."
echo "Build with APPLY_SITE_OVERLAY=true (set it in .env) to bake the overlay into the local image."
