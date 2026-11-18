# Troubleshooting

## First checks

```bash
docker compose ps
docker compose logs --tail=200
curl -s http://127.0.0.1:8080/ping        # pong
```

The container healthcheck uses `/ping`; a container can be "healthy" while the
tuner is not connected yet.

## Symptom table

| Symptom | Likely cause / fix |
|---|---|
| `ERROR: /data is not writable by uid 1000` | `data/` created by root. Fix: `sudo chown -R 1000:1000 data` or run `make bootstrap` before `make up`. |
| Container restarts / `Error opening port` | Serial device missing or permissions. Check `TUNER_DEVICE`, `ls -l /dev/ttyACM*`, groups (`dialout`/`audio`), udev rule. |
| Page loads but audio is silent | Wrong `audio.audioDevice`; ALSA device busy; test with `arecord` on the host first. |
| Spectrum/RDS empty | Tuner not connected or on the wrong antenna; check `docs/HARDWARE.md`. |
| Plugins fail with `403 Forbidden` / empty plugin panels | The localhost ban/anti-spam patch is missing or an old image is running. `docker compose build --no-cache` and check `grep MM_LOCALHOST_SPAM_BYPASS` in the image. |
| `text` WebSocket reconnects via the proxy | Proxy is missing the `Upgrade`/`Connection` headers or has a short `proxy_read_timeout`; see `docs/REVERSE-PROXY.md`. |
| `Waiting for Scope..` / empty MPX | MPX input card not configured or busy; check `data/plugins_configs/metricsmonitor.json` and the `MPXCapture` logs. |
| Scanner logs not written | `data/logs/` permissions; check `docker compose logs` for the scanner plugin. |
| Disk filling up | Scanner logs: `make prune-logs` (90 days) or `DAYS=30 make prune-logs`. |
| `exec format error` for MPXCapture | Image built for another architecture (the build keeps the target-arch binary). |
| Healthcheck shows unhealthy but the UI works | Check `/ping` inside the container: `docker compose exec fm-dx-webserver wget -qO- http://127.0.0.1:8080/ping`. |

## Useful commands

```bash
# serial and audio inside the container
docker compose exec fm-dx-webserver ls -l /dev/ttyACM* /dev/snd
docker compose exec fm-dx-webserver arecord -l
docker compose exec fm-dx-webserver arecord -D hw:CARD=Scarlett,DEV=0 -f S16_LE -r 48000 -c 2 -d 5 /tmp/t.wav

# which plugins loaded
docker compose logs | grep -E 'Plugin .* initialized'

# image patch markers
docker run --rm --entrypoint sh fm-dx-webserver:local -c \
  'grep -l MM_ server/helpers.js web/js/main.js server/tx_search.js web/js/webserver.js'
```

## Seeded data

On first start `seed-data.sh` copies defaults to `data/`. If you want to reset a
plugin, stop the container and delete the relevant file in `data/` (for example
`data/plugins_configs/scanner.json`), then start again.

## Reporting a problem

Include the image tag/commit, `docker compose config` (redact secrets), the
relevant log lines and what you already checked. Do not paste
`config/config.json` without redacting passwords and the FMLIST token.
