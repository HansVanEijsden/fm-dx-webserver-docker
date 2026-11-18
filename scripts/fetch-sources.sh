#!/bin/sh
# Fetch the pinned upstream core and plugin sources and assemble the app tree.
# Runs inside the Docker "fetch" stage. Requires git and network access.
set -eu

SRC=${1:-/src}
APP="$SRC/app"
VERSIONS="$SRC/versions.env"

[ -f "$VERSIONS" ] || { echo "missing $VERSIONS" >&2; exit 1; }
# shellcheck disable=SC1090
. "$VERSIONS"

# Optional override from the build arg.
CORE_REF=${FM_DX_REF:-$CORE_REF}

fetch_ref() {
    repo=$1
    ref=$2
    dest=$3
    rm -rf "$dest"
    mkdir -p "$dest"
    (
        cd "$dest"
        git init -q
        git fetch -q --depth 1 "$repo" "$ref"
        git checkout -q FETCH_HEAD
        rm -rf .git
    )
}

echo "Fetching core $CORE_REPO @ $CORE_REF"
fetch_ref "$CORE_REPO" "$CORE_REF" "$APP"

mkdir -p "$APP/plugins"
mkdir -p "$SRC/.plugins"

printf '%s\n' "$PLUGINS" | while IFS='|' read -r name repo ref dir wrapper; do
    [ -n "${name:-}" ] || continue
    case "$name" in \#*) continue ;; esac
    echo "Fetching plugin $name @ $ref"
    tmp="$SRC/.plugins/$name"
    fetch_ref "$repo" "$ref" "$tmp"

    mkdir -p "$APP/plugins/$name"
    cp -a "$tmp/$dir/." "$APP/plugins/$name/"

    if [ -n "${wrapper:-}" ] && [ -f "$tmp/$wrapper" ]; then
        cp "$tmp/$wrapper" "$APP/plugins/$(basename "$wrapper")"
    else
        echo "ERROR: wrapper '$wrapper' not found for plugin $name" >&2
        exit 1
    fi
    rm -rf "$tmp"
done

# Ensure the bundled capture binary is executable.
find "$APP/plugins" -path '*/bin/*/MPXCapture' -type f -exec chmod +x {} + 2>/dev/null || true

echo "Sources assembled in $APP"
