# Configuration

## Layout

| Path | Mounted at | Contents |
|---|---|---|
| `config/config.json` | `/opt/fm-dx-webserver/config.json` | main configuration |
| `data/plugins_configs/` | `/opt/fm-dx-webserver/plugins_configs/` | per-plugin settings |
| `data/scanner/` | `/data/scanner/` (symlinked into the Scanner plugin) | blacklist, whitelist, FMLIST list, scan state |
| `data/rds/` | `/data/rds/` (symlinked into the RDS AI Decoder) | AI cache and state |
| `data/logs/` | `/opt/fm-dx-webserver/web/logs/` | scanner HTML/CSV logs |
| `data/serverlog.txt` | `/opt/fm-dx-webserver/serverlog.txt` | application log |

`config/`, `data/`, `site/` and `.env` are gitignored. Back up with
`make backup`.

## config.json

The schema is the upstream FM-DX Webserver 1.4.2 schema. The important sections:

- `webserver`: bind address/port, presets, theme, chat, RDS mode, bans.
- `xdrd`: serial device (`comPort`) and port for wireless XDR receivers.
- `audio`: `audioDevice` (ALSA device), channels, bitrate, volume.
- `identification`: tuner name, description, coordinates, FMLIST token,
  public URL (`proxyIp`), contact.
- `password`: `tunePass` and `adminPass`.
- `antennas`, `extras`, `tunnel`: optional features.
- `plugins`: list of enabled plugin entry points (relative to the `plugins/`
  directory). Remove an entry to disable a plugin without rebuilding.
- `device`: `tef` (TEF6686) or `si47xx`.

Starting from `examples/config.example.json`, change at least:

- `identification.tunerName`, `lat`, `lon`, `token`, `proxyIp`
- `password.tunePass`, `password.adminPass`
- `audio.audioDevice`
- `xdrd.comPort` (or set `TUNER_DEVICE` before starting)

The file is written by the application when settings change. Keep it at mode
`0600` and never commit it.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `TZ` | `Europe/Amsterdam` | container timezone |
| `BIND_IP` | `0.0.0.0` | host address to publish port 8080 on |
| `HOST_PORT` | `8080` | host port |
| `TUNER_DEVICE` | `/dev/ttyACM0` | serial device passed to the container |
| `AUDIO_GID` | `29` | host audio group id (device access) |
| `DIALOUT_GID` | `20` | host dialout group id (serial access) |
| `FM_DX_DEBUG` | `false` | run the app with `--debug` |
| `FM_DX_FFMPEG_DEBUG` | `false` | run with `--ffmpegdebug` |
| `APPLY_SITE_OVERLAY` | `false` | bake `site/overlay/` into the local image |
| `IMAGE_TAG` | `local` | local image tag |
| `NODE_IMAGE` | `node:26-alpine` | base image (pin the digest in CI/releases) |

`make bootstrap` fills the device and group IDs automatically.

## Plugins

The image ships the plugins pinned in `versions.env`. Their entry points are
listed in `config.json` → `plugins`. Plugin settings are generated in
`data/plugins_configs/` on first start; delete a file to reset that plugin.

Scanner lists live in `data/scanner/`:

- `blacklist.txt`, `whitelist.txt` — frequencies to skip/force
- `blacklist_fmlist.txt` — FMLIST blacklist
- `scanner_state.json` — active scanner profile

## Secrets

`config.json` contains the admin/tune passwords and the FMLIST token, and
`data/` may contain location data. Keep:

```bash
chmod 600 config/config.json
```

Out of git, out of the Docker build context, and out of issue reports.
