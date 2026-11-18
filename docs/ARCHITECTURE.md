# Architecture

## Build pipeline

```
versions.env (pinned SHAs)
        │
        ▼
┌─────────────┐   git fetch --depth 1 per repo
│ fetch stage │────────────────────────────────┐
└─────────────┘                                │
                                               ▼
                                   /src/app (core + plugins/ + wrappers)
                                               │
                                               ▼
┌─────────────┐   npm ci                     ┌──────────────────────────┐
│ build stage │─────────────────────────────▶│ patches/core/*.patch     │
└─────────────┘                              │ patches/plugins/*.patch  │
                                             │ patch-rds-txsearch.js    │
                                             │ site/overlay (optional)  │
                                             │ prune binaries/ffmpeg    │
                                             │ seed defaults + symlinks │
                                             └────────────┬─────────────┘
                                                          │
                                                          ▼
┌──────────────┐   node:26-alpine + alsa-utils + ffmpeg
│ runtime stage│   COPY --chown=1000:1000, USER 1000, /data, healthcheck
└──────────────┘
```

- The upstream sources are **not vendored**: the build fetches each repository
  at the full commit SHA from `versions.env`.
- `npm ci` uses the upstream lockfile. `npm audit fix` is intentionally not run
  (it would make builds non-deterministic).
- Compatibility patches are applied with `git apply --check`; a build fails if a
  patch no longer applies.

## Patches

| Patch | Purpose |
|---|---|
| `core/helpers-localhost-ban.patch` | loopback plugins bypass the anti-spam and banlist (1.4.2 enforces bans on WebSocket upgrades) |
| `core/main-js-compat.patch` | tolerate missing `rt0_errors`/`rt1_errors` and compare HTML without `aria-describedby` (stops flag flicker) |
| `core/tx-search-cache.patch` | drop the PI+PS cache so a reset cannot leave the station card empty |
| `core/webserver-tooltip-order.patch` | load `tooltip.js` before `main.js` (fixes a Safari `initTooltips` race) |
| `plugins/metricsmonitor-header-ecc.patch` | rebuild the ECC badge only when its content changes |
| `plugins/ai-denoise-ort-quiet.patch` | filter harmless ONNX runtime warnings from the console |
| `core/stream-parser-ffmpeg.patch` | use the system ffmpeg instead of the pruned `ffmpeg-static` package |
| `core/client-ip-trust.patch` | prefer the proxy-set `X-Real-IP` and use it for admin login logs |

`scripts/patch-rds-txsearch.js` pre-applies the RDS AI Decoder's AI-override
patch to `server/tx_search.js`, so the first boot does not need a restart. If a
plugin update changes the signatures, the build fails.

Each patch carries a marker comment (for example `// MM_ARIA_SAFE_COMPARE:`), and
`scripts/verify.sh` asserts the markers are present in the built image.

## Site overlay

`site/overlay/` is copied over the app tree after patches when
`APPLY_SITE_OVERLAY=true` (set in `.env`). It is meant for local plugin
customisations (visualisations, calibration, preset files) and is gitignored.
`config/` and `data/` are never copied into the image.

## Runtime

- The container runs as uid/gid 1000, with `cap_drop: ALL` and
  `no-new-privileges`. `systempaths=unconfined` is required because the admin
  Audio page reads `/proc/asound` (masked by Docker by default); `eudev`
  provides `udevadm` for device discovery.
- `/data` is a persistent volume. Mutable plugin files are symlinked to it at
  build time; `seed-data.sh` creates the files on first start.
- `plugins_configs` and `web/logs` are mounted from `data/`.
- The healthcheck calls `GET /ping` (returns `pong`).
- `init: true` reaps child processes (arecord, ffmpeg, MPXCapture).

### Persistence matrix

| State | Location |
|---|---|
| app config, passwords, token | `config/config.json` |
| plugin settings | `data/plugins_configs/` |
| scanner lists + state | `data/scanner/` |
| RDS AI cache/state | `data/rds/` |
| scanner logs | `data/logs/` |
| application log | `data/serverlog.txt` |

The web client files that plugins deploy (`web/js/plugins/`) are regenerated at
startup and not persisted.

## CI and releases

- `ci.yml`: hadolint, shellcheck, build, patch-marker checks, non-root check,
  smoke test, Trivy, gitleaks.
- `release.yml`: on `v*` tags, builds and pushes
  `ghcr.io/<owner>/fm-dx-webserver-docker` with SBOM and provenance.
- `upstream-check.yml`: weekly check that every pinned ref still exists and
  shows upstream drift.
