# Local site overlay (gitignored)

This directory is for **site-specific** plugin files and assets that are not
part of the public generic image: local visual customisations, a modified
plugin build, a preset file with personal frequencies, etc.

- `site/overlay/` is copied over the assembled app tree during `docker build`
  when `APPLY_SITE_OVERLAY=true` (after the pinned sources and compatibility
  patches are applied).
- Never put `config.json`, passwords, API tokens or other secrets here. They
  belong in `config/` and `data/`, which are also gitignored.
- `scripts/export-site.sh` can copy the customisations from an existing
  installation into `site/overlay/`.
- Everything except this README is ignored by git, so `git status` stays clean.
