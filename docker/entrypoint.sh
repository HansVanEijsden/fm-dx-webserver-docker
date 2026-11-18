#!/bin/sh
# Container entrypoint: seed persistent state, then replace the shell with node.
set -eu

/usr/local/bin/seed-data.sh

set -- index.js
if [ "${FM_DX_DEBUG:-false}" = "true" ]; then
    set -- "$@" --debug
fi
if [ "${FM_DX_FFMPEG_DEBUG:-false}" = "true" ]; then
    set -- "$@" --ffmpegdebug
fi

exec node "$@"
