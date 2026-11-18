# FM-DX Webserver Docker

[![CI](https://github.com/HansVanEijsden/fm-dx-webserver-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/HansVanEijsden/fm-dx-webserver-docker/actions/workflows/ci.yml)

A reproducible, hardened Docker setup for
[FM-DX Webserver](https://github.com/NoobishSVK/fm-dx-webserver) with a curated
set of plugins, built from **pinned upstream commits**.

This is an unofficial packaging project. The upstream application and plugins
remain the work of their authors (see [NOTICE](NOTICE)).

## What you get

- Upstream core and plugins fetched at immutable commit SHAs (`versions.env`).
- Compatibility patches applied **at build time**, not by a start-up script.
- The RDS AI Decoder `tx_search.js` patch is pre-applied, so a fresh container
  starts without an extra restart.
- Non-root container, no `privileged`, healthcheck, log limits and a persistent
  `/data` volume.
- Reproducible image build, CI (lint, build, smoke test, vulnerability scan) and
  a release workflow that publishes to GHCR.
- English documentation for hardware, reverse proxies, upgrades and
  troubleshooting.

## Requirements

- Linux x86_64 (arm64 is experimental), Docker 24+ with Compose v2.
- An ALSA capture device (sound card line-in or USB audio interface).
- A TEF6686 USB serial tuner (tested with `1209:6687`, `/dev/ttyACM0`).
- Optional: a reverse proxy with WebSocket support (nginx, Caddy, Cloudflare,
  Tailscale) for public access.

## Quick start

```bash
git clone https://github.com/HansVanEijsden/fm-dx-webserver-docker.git
cd fm-dx-webserver-docker

make bootstrap          # creates .env and config/config.json (mode 0600)
$EDITOR config/config.json   # tuner name, lat/lon, passwords, audio device

make build
make up
```

Open `http://<host>:8080` (or configure a reverse proxy, see
[docs/REVERSE-PROXY.md](docs/REVERSE-PROXY.md)). Health endpoint:
`curl http://<host>:8080/ping` → `pong`.

`make bootstrap` detects the serial device and the `audio`/`dialout` group IDs.
It can also fill config values from environment variables:

```bash
TUNER_NAME="My tuner" TUNER_LAT=52.0 TUNER_LON=6.0 \
ADMIN_PASS=secret TUNE_PASS=secret FMLIST_TOKEN=... PROXY_URL=https://tuner.example.com \
make bootstrap
```

## Hardware

- **Audio:** any ALSA capture device. List them with `arecord -l` and set
  `audio.audioDevice` to the card, for example `hw:CARD=Scarlett,DEV=0`.
- **Tuner:** the TEF6686 appears as `/dev/ttyACM0`. For stable naming and
  non-root access, install the example udev rule in
  [docs/HARDWARE.md](docs/HARDWARE.md).
- **MPX/Signal:** needs a second audio input for the MPX signal; configure
  `MPXInputCard` in `data/plugins_configs/metricsmonitor.json`. The spectrum,
  RDS and scanner work with the tuner alone.

## Configuration and data

| Path | Purpose |
|---|---|
| `config/config.json` | web server, tuner, audio, identity and plugin list |
| `data/plugins_configs/` | per-plugin settings (mounted) |
| `data/scanner/` | scanner blacklist/whitelist/state (mounted) |
| `data/rds/` | RDS AI Decoder cache/state (mounted) |
| `data/logs/` | scanner logs (mounted at `web/logs`) |
| `data/serverlog.txt` | application log |

All of it is gitignored. Back up with `make backup`.

If `data/` is created by Docker as `root`, the non-root container cannot write
to it. Always run `make bootstrap` first (or `chown -R 1000:1000 data`).

## Updating

1. `make backup`
2. Update the commit SHAs in `versions.env` (and/or run `make update` to see
   upstream drift).
3. `make verify` — fails when a compatibility patch no longer applies.
4. `make build && make up`.

Never force a plugin update past a failing patch: regenerate the patch against
the new upstream file and re-test. See
[docs/UPGRADING.md](docs/UPGRADING.md).

## Site-specific customisations

Local plugin customisations (visualisations, calibration, preset frequencies)
belong in `site/overlay/` and are copied into the image after the patches when
`APPLY_SITE_OVERLAY=true` is set in `.env`. They are gitignored. Use
`scripts/export-site.sh` to migrate them from an existing installation.

## Security

- Container runs as uid/gid 1000, drops all capabilities and sets
  `no-new-privileges`.
- No secrets are baked into the image; `config/` and `.env` are excluded from the
  build context.
- `8080` is published on all interfaces by default. Set `BIND_IP` to
  `127.0.0.1` when the proxy runs on the same host, or to the Tailscale/LAN
  address when a proxy elsewhere must reach it.
- See [SECURITY.md](SECURITY.md).

## Documentation

- [Hardware and permissions](docs/HARDWARE.md)
- [Reverse proxy](docs/REVERSE-PROXY.md)
- [Configuration](docs/CONFIGURATION.md)
- [Architecture and patches](docs/ARCHITECTURE.md)
- [Upgrading](docs/UPGRADING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md)

## License

GPL-3.0. The image combines GPL-3.0 upstream projects; see [NOTICE](NOTICE) for
attribution and pinned source references.
