# syntax=docker/dockerfile:1.7

ARG NODE_IMAGE=node:26-alpine

# ---------------------------------------------------------------------------
# fetch: clone the pinned upstream core and plugin sources
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS fetch
ARG FM_DX_REF=
RUN apk add --no-cache git ca-certificates
WORKDIR /src
COPY versions.env /src/versions.env
COPY scripts/fetch-sources.sh /src/fetch-sources.sh
RUN chmod +x /src/fetch-sources.sh && /src/fetch-sources.sh /src

# ---------------------------------------------------------------------------
# build: install dependencies, apply compatibility patches, add site overlay
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS build
RUN apk add --no-cache --virtual .build-deps \
        build-base gcc cmake musl-dev python3 git
WORKDIR /opt/fm-dx-webserver
COPY --from=fetch /src/app/ ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY patches/ /opt/patches/
COPY scripts/apply-patches.sh scripts/patch-rds-txsearch.js /usr/local/bin/
RUN chmod +x /usr/local/bin/apply-patches.sh \
 && /usr/local/bin/apply-patches.sh /opt/fm-dx-webserver \
 && node /usr/local/bin/patch-rds-txsearch.js /opt/fm-dx-webserver

# Optional local overlay (site-specific plugin code/assets). Never contains config.
ARG APPLY_SITE_OVERLAY=false
COPY site/ /tmp/site/
RUN if [ "$APPLY_SITE_OVERLAY" = "true" ] && [ -d /tmp/site/overlay ]; then \
        cp -a /tmp/site/overlay/. /opt/fm-dx-webserver/; \
    fi

# Keep only the MPXCapture binary for the target architecture and drop the
# unused ffmpeg-static fallback (system ffmpeg is installed in the runtime).
ARG TARGETARCH=amd64
RUN set -e; \
    case "$TARGETARCH" in \
        amd64) keep=linux-x64 ;; \
        arm64) keep=linux-arm64 ;; \
        *)     keep=linux-x64 ;; \
    esac; \
    bin_dir=/opt/fm-dx-webserver/plugins/MetricsMonitor/bin; \
    if [ -d "$bin_dir" ]; then \
        for d in "$bin_dir"/*; do \
            [ "$(basename "$d")" = "$keep" ] || rm -rf "$d"; \
        done; \
        chmod +x "$bin_dir/$keep/MPXCapture" 2>/dev/null || true; \
    fi; \
    rm -rf /opt/fm-dx-webserver/node_modules/ffmpeg-static

# ES Alert plays /sound/alert.mp3 from the web root; ship the plugin's sound file.
RUN base=/opt/fm-dx-webserver; \
    mkdir -p "$base/web/sound"; \
    if [ -f "$base/plugins/ES-Alert/alert.mp3" ]; then cp "$base/plugins/ES-Alert/alert.mp3" "$base/web/sound/alert.mp3"; fi

# Seed data + redirect mutable runtime state to /data (persistent volume).
RUN set -e; \
    base=/opt/fm-dx-webserver; \
    mkdir -p "$base/defaults/scanner" "$base/defaults/rds"; \
    for f in blacklist.txt whitelist.txt blacklist_fmlist.txt blacklist_log.txt scanner_state.json; do \
        src="$base/plugins/Scanner/$f"; \
        if [ -f "$src" ] && [ ! -L "$src" ]; then cp "$src" "$base/defaults/scanner/$f"; elif [ "$f" = "scanner_state.json" ]; then echo '{}' > "$base/defaults/scanner/$f"; else : > "$base/defaults/scanner/$f"; fi; \
        ln -sf "/data/scanner/$f" "$base/plugins/Scanner/$f"; \
    done; \
    for f in rdsm_config.json rdsm_fmdx_cache.json rdsm_memory.json; do \
        src="$base/plugins/RDS-AI-Decoder/$f"; \
        if [ -f "$src" ] && [ ! -L "$src" ]; then cp "$src" "$base/defaults/rds/$f"; fi; \
        ln -sf "/data/rds/$f" "$base/plugins/RDS-AI-Decoder/$f"; \
    done; \
    ln -sf /data/serverlog.txt "$base/serverlog.txt"

# ---------------------------------------------------------------------------
# runtime
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE}
RUN apk add --no-cache bash alsa-utils ffmpeg ca-certificates

WORKDIR /opt/fm-dx-webserver
COPY --from=build --chown=1000:1000 /opt/fm-dx-webserver /opt/fm-dx-webserver
COPY --chown=1000:1000 docker/entrypoint.sh docker/seed-data.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/seed-data.sh \
 && mkdir -p /data && chown 1000:1000 /data

ENV NODE_ENV=production \
    TZ=Europe/Amsterdam

USER 1000:1000
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/ping || exit 1

LABEL org.opencontainers.image.title="fm-dx-webserver-docker" \
      org.opencontainers.image.description="Reproducible FM-DX Webserver container with pinned plugins" \
      org.opencontainers.image.url="https://github.com/HansVanEijsden/fm-dx-webserver-docker" \
      org.opencontainers.image.source="https://github.com/HansVanEijsden/fm-dx-webserver-docker" \
      org.opencontainers.image.licenses="GPL-3.0"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
