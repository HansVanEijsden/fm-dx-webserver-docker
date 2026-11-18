#!/bin/sh
# Apply the local compatibility patches to the assembled app tree.
# Usage: apply-patches.sh [APP_ROOT] [--check]
#   --check  only verify that every patch applies (used by CI)
set -eu

APP=/opt/fm-dx-webserver
MODE=apply
for arg in "$@"; do
    case "$arg" in
        --check) MODE=check ;;
        /*)      APP=$arg ;;
        *)       APP=$arg ;;
    esac
done

PATCH_ROOT=${PATCH_ROOT:-/opt/patches}

[ -d "$APP" ] || { echo "app root not found: $APP" >&2; exit 1; }
[ -d "$PATCH_ROOT" ] || { echo "patch root not found: $PATCH_ROOT" >&2; exit 1; }

cd "$APP"

for patch in "$PATCH_ROOT"/core/*.patch "$PATCH_ROOT"/plugins/*.patch; do
    [ -f "$patch" ] || continue
    if ! git apply --check "$patch"; then
        echo "ERROR: patch does not apply: $patch" >&2
        exit 1
    fi
    if [ "$MODE" = "apply" ]; then
        git apply "$patch"
        echo "applied $(basename "$patch")"
    else
        echo "ok $(basename "$patch")"
    fi
done

echo "patch check complete"
