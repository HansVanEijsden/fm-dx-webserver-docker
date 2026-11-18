# Upgrading

The image is reproducible because every upstream source is pinned in
`versions.env`. Upgrades are explicit and testable.

## Routine upgrade

```bash
make backup
make update          # shows pinned vs upstream HEAD/tag; fails on a missing pin
$EDITOR versions.env # bump the relevant refs to full commit SHAs
make verify          # build + patch checks + smoke test
make build && make up
```

`make update` is informational for newer upstream commits and exits non-zero
only when a pinned commit can no longer be fetched (for example after a
force-push or repository removal).

## When a patch fails

A failed `git apply --check` aborts the build with the patch name. That is
intentional: never skip a patch silently.

1. Fetch the old and new upstream file, for example:
   ```bash
   git clone https://github.com/NoobishSVK/fm-dx-webserver.git /tmp/up
   cd /tmp/up && git checkout <old-sha> && cp server/helpers.js /tmp/old.js
   git checkout <new-sha> && cp server/helpers.js /tmp/new.js
   ```
2. Re-apply the fix manually to `/tmp/new.js` (the marker comment tells you what
   the patch does) and verify the behaviour.
3. Regenerate the patch with byte-exact paths:
   ```bash
   diff -u --label a/server/helpers.js --label b/server/helpers.js \
     /tmp/new.js /tmp/patched.js > patches/core/helpers-localhost-ban.patch
   ```
4. `make verify` and include the upstream ref bump in the same commit.

Keep one patch per concern and keep the marker comments: CI checks them.

## RDS AI Decoder

`scripts/patch-rds-txsearch.js` mirrors the patcher of the pinned plugin
version. If the plugin update changes the `fetchTx` signature or the exports,
the build fails with a clear message; update the script together with
`versions.env`.

## Base image and Actions

The base image digest and GitHub Actions versions are updated by Renovate (or
manually). Always run `make verify` after a base image bump: native modules
(`serialport`) and ALSA access are the sensitive parts.

## Rollback

- Keep the previous image tag, for example:
  ```bash
  docker tag fm-dx-webserver:local fm-dx-webserver:previous
  ```
  To roll back: `docker compose down`, restore the tag, `docker compose up -d`.
- Config and data roll back via `make backup` / the tarball in `backups/`.
- The repository history (`git log`) shows every pin and patch change.
