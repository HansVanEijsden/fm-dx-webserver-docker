#!/bin/sh
# Show upstream drift for the pinned core and plugin versions.
# Usage: update-pins.sh [--check]
#   --check  exit non-zero when a pinned ref can no longer be fetched
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_DIR"
# shellcheck disable=SC1091
. ./versions.env

MODE=${1:-}
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

lookup() {
    name=$1
    repo=$2
    ref=$3

    head_info=$(git ls-remote --symref "$repo" HEAD 2>/dev/null | head -1 || true)
    head_ref=$(printf '%s\n' "$head_info" | awk '{print $2}')
    head_sha=$(git ls-remote "$repo" HEAD 2>/dev/null | awk '{print $1}' || true)
    latest_tag=$(git ls-remote --tags --refs "$repo" 2>/dev/null | awk -F/ '{print $NF}' | sort -V | tail -1 || true)

    rm -rf "$TMP/repo"
    if git init -q "$TMP/repo" 2>/dev/null && git -C "$TMP/repo" fetch -q --depth 1 "$repo" "$ref" 2>/dev/null; then
        pin_state="ok"
    else
        pin_state="MISSING"
        FAIL=1
    fi

    printf '%-16s pinned %-40s %-8s upstream %s %s (latest tag: %s)\n' \
        "$name" "$ref" "$pin_state" "${head_ref:-HEAD}" "${head_sha:-?}" "${latest_tag:-none}"
}

printf '%-16s %s\n' "source" "state"
lookup core "$CORE_REPO" "$CORE_REF"

while IFS='|' read -r name repo ref dir wrapper; do
    [ -n "${name:-}" ] || continue
    case "$name" in \#*) continue ;; esac
    lookup "$name" "$repo" "$ref"
done <<EOF
$PLUGINS
EOF

if [ "$MODE" = "--check" ]; then
    exit "$FAIL"
fi
