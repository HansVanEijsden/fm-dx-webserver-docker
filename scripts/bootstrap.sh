#!/bin/sh
# Create .env and config/config.json for a fresh install.
# Existing files are never overwritten.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: Docker Compose v2 is required" >&2; exit 1; }

if [ ! -f .env ]; then
    AUDIO_GID=$(getent group audio 2>/dev/null | cut -d: -f3 || true)
    DIALOUT_GID=$(getent group dialout 2>/dev/null | cut -d: -f3 || true)
    TUNER_DEVICE=$(ls /dev/ttyACM* 2>/dev/null | head -1 || true)
    [ -n "${AUDIO_GID:-}" ] || AUDIO_GID=29
    [ -n "${DIALOUT_GID:-}" ] || DIALOUT_GID=20
    [ -n "${TUNER_DEVICE:-}" ] || TUNER_DEVICE=/dev/ttyACM0
    cat > .env <<EOF
TZ=${TZ:-Europe/Amsterdam}
BIND_IP=${BIND_IP:-0.0.0.0}
HOST_PORT=${HOST_PORT:-8080}
TUNER_DEVICE=$TUNER_DEVICE
AUDIO_GID=$AUDIO_GID
DIALOUT_GID=$DIALOUT_GID
FM_DX_DEBUG=false
FM_DX_FFMPEG_DEBUG=false
APPLY_SITE_OVERLAY=false
IMAGE_TAG=local
EOF
    echo "Created .env (tuner: $TUNER_DEVICE, audio gid: $AUDIO_GID)"
fi

mkdir -p data/plugins_configs data/logs data/scanner data/rds
chmod -R u+rwX data 2>/dev/null || true
[ -e data/serverlog.txt ] || : > data/serverlog.txt

if [ ! -f config/config.json ]; then
    cp examples/config.example.json config/config.json
    chmod 600 config/config.json
    if command -v python3 >/dev/null 2>&1 && \
       { [ -n "${TUNER_NAME:-}" ] || [ -n "${TUNER_LAT:-}" ] || [ -n "${TUNER_LON:-}" ] || \
         [ -n "${ADMIN_PASS:-}" ] || [ -n "${TUNE_PASS:-}" ] || [ -n "${FMLIST_TOKEN:-}" ] || \
         [ -n "${PROXY_URL:-}" ]; }; then
        TUNER_NAME="${TUNER_NAME:-}" TUNER_LAT="${TUNER_LAT:-}" TUNER_LON="${TUNER_LON:-}" \
        ADMIN_PASS="${ADMIN_PASS:-}" TUNE_PASS="${TUNE_PASS:-}" FMLIST_TOKEN="${FMLIST_TOKEN:-}" \
        PROXY_URL="${PROXY_URL:-}" python3 - <<'PY'
import json, os
path = "config/config.json"
with open(path) as fh:
    cfg = json.load(fh)
if os.environ.get("TUNER_NAME"):
    cfg["identification"]["tunerName"] = os.environ["TUNER_NAME"]
if os.environ.get("TUNER_LAT"):
    cfg["identification"]["lat"] = os.environ["TUNER_LAT"]
if os.environ.get("TUNER_LON"):
    cfg["identification"]["lon"] = os.environ["TUNER_LON"]
if os.environ.get("ADMIN_PASS"):
    cfg["password"]["adminPass"] = os.environ["ADMIN_PASS"]
if os.environ.get("TUNE_PASS"):
    cfg["password"]["tunePass"] = os.environ["TUNE_PASS"]
if os.environ.get("FMLIST_TOKEN"):
    cfg["identification"]["token"] = os.environ["FMLIST_TOKEN"]
if os.environ.get("PROXY_URL"):
    cfg["identification"]["proxyIp"] = os.environ["PROXY_URL"]
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
    fi
    echo "Created config/config.json (mode 0600)."
    echo "Set the tuner name, coordinates, passwords and FMLIST token in"
    echo "config/config.json, or use the admin settings in the web UI."
fi

if command -v arecord >/dev/null 2>&1; then
    echo
    echo "Capture devices found by ALSA (use the card name in audio.audioDevice):"
    arecord -l 2>/dev/null | sed -n 's/^card \([0-9]*\): \([^ ]*\).*/  card \1: \2/p' || true
fi

echo
echo "Next: make build && make up"
echo "Web UI: http://<host>:${HOST_PORT:-8080}"
