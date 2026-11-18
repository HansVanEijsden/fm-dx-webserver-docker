#!/bin/sh
# Smoke test: start the image without hardware and wait for /ping.
set -eu

IMAGE=${1:-fm-dx-webserver:verify}
NAME="fm-dx-smoke-$$"
PORT=${SMOKE_PORT:-18080}
URL="http://127.0.0.1:$PORT/ping"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$NAME" \
    -p "127.0.0.1:$PORT:8080" \
    -e TZ=UTC \
    "$IMAGE" >/dev/null

attempt=0
ok=0
while [ "$attempt" -lt 90 ]; do
    if curl -fsS "$URL" 2>/dev/null | grep -q pong; then
        ok=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done

if [ "$ok" != "1" ]; then
    echo "ERROR: /ping did not become ready" >&2
    docker logs "$NAME" 2>&1 | tail -60 >&2 || true
    exit 1
fi

docker logs "$NAME" 2>&1 | grep -q "Web server has started" || {
    echo "ERROR: web server start line not found in logs" >&2
    docker logs "$NAME" 2>&1 | tail -60 >&2
    exit 1
}

echo "smoke ok (port $PORT)"
