# Contributing

Thanks for helping improve this packaging project. The upstream application and
plugins belong to their authors; this repository only provides the container,
pinning, patches and documentation.

## Ground rules

- Never commit `config/`, `data/`, `site/overlay/`, `.env` or backups.
- Keep builds reproducible: every source is pinned by full commit SHA.
- One patch per concern, with a marker comment (for example
  `// MM_ARIA_SAFE_COMPARE:`); CI checks the markers.
- Run `make verify` before opening a pull request.

## Adding or updating a plugin

1. Add/modify a row in `versions.env`:
   ```
   Name|https://github.com/owner/repo.git|<full-sha>|<plugin-dir>|<wrapper.js>
   ```
2. Add the plugin's entry point to `examples/config.example.json` and the
   `plugins` list if it should be enabled by default.
3. Plugin settings belong in `data/plugins_configs/` at runtime; do not add
   personal settings to the repo.
4. Run `make verify`; the build fetches and installs the plugin.

## Changing a compatibility patch

1. Fetch the old and new upstream file at the pinned commits.
2. Apply the intended change to the new file and test the behaviour.
3. Generate a byte-exact diff:
   ```bash
   diff -u --label a/<path> --label b/<path> old.js new.js > patches/<area>/<name>.patch
   ```
4. `git apply --check patches/<area>/<name>.patch` from the app root (the build
   does this automatically).
5. Keep the marker comment and update `docs/ARCHITECTURE.md` if the patch list
   changes.

## Style

- Shell: POSIX `sh`, `shellcheck -x` clean.
- Dockerfile: hadolint clean (see `.hadolint.yaml`).
- Markdown: one sentence per line is welcome but not required.
- Commit messages: imperative subject, explain the why in the body.

## Pull request checklist

- [ ] `make verify` passes (build, patch markers, smoke test).
- [ ] No secrets or personal data in the diff.
- [ ] Docs updated for behaviour changes.
- [ ] `versions.env` changes use full commit SHAs.
