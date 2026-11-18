#!/bin/sh
# Verify patches, build the image and run the smoke test.
set -eu

REPO_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"

IMAGE=${IMAGE:-fm-dx-webserver:verify}

echo "==> Building $IMAGE from pinned sources"
docker build -t "$IMAGE" --build-arg APPLY_SITE_OVERLAY=false .

echo "==> Checking patched files"
docker run --rm --entrypoint sh "$IMAGE" -c '
set -e
grep -q MM_LOCALHOST_SPAM_BYPASS server/helpers.js
grep -q MM_ARIA_SAFE_COMPARE web/js/main.js
grep -q MM_NO_TX_CACHE server/tx_search.js
grep -q MM_TOOLTIP_ORDER web/js/webserver.js
grep -q MM_ECC_STABLE_BADGE plugins/MetricsMonitor/js/metricsmonitor-header.js
grep -q MM_ORT_QUIET plugins/AI-Denoise/ai-denoise.js
grep -q MM_SYSTEM_FFMPEG server/stream/parser.js
grep -q setAiOverride server/tx_search.js
echo "all patch markers present"
'

echo "==> Checking runtime user"
[ "$(docker run --rm --entrypoint id "$IMAGE" -u)" = "1000" ] || {
    echo "ERROR: image does not run as uid 1000" >&2
    exit 1
}

echo "==> Smoke test"
"$REPO_DIR/tests/smoke.sh" "$IMAGE"

echo "verify ok"
