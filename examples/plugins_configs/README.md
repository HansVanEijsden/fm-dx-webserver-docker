# Plugin configuration examples

Plugin settings are stored in `data/plugins_configs/` (mounted at
`/opt/fm-dx-webserver/plugins_configs`). On first start each plugin creates its
default configuration there. Copy a file from this directory into
`data/plugins_configs/` before the first start if you want to seed specific
settings.

Scanner-specific data lives in `data/scanner/` (blacklist, whitelist, FMLIST
lists and scanner state) and RDS AI Decoder state in `data/rds/`; see the
`scripts/export-site.sh` helper when migrating an existing installation.

For a minimal first run no files are needed: the plugins generate their
defaults and the tuner can be configured from the admin UI.
