# Security policy

## Supported versions

The `main` branch and the most recent release image. This is a packaging
project; upstream security fixes are adopted by bumping the pinned refs in
`versions.env` and rebuilding.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private
vulnerability reporting (Security → Advisories → Report a vulnerability) on this
repository, or contact the maintainer through the address in the repository
profile. Include the image tag/commit, reproduction steps and impact.

## This project's security model

- The container runs as uid/gid 1000, drops all capabilities and sets
  `no-new-privileges`.
- `config/`, `data/`, `site/` and `.env` are excluded from git and from the
  Docker build context; no secrets are baked into the image.
- `8080` is published on `0.0.0.0` by default. Restrict it with `BIND_IP`, a
  firewall or Tailscale ACLs, and terminate TLS in a reverse proxy.
- Images are scanned with Trivy in CI (report; critical findings are fixed by
  rebuilding on a newer base image).
- Dependencies are pinned by the upstream lockfile and the base image is pinned
  per release.

## Out of scope

Vulnerabilities in the upstream FM-DX Webserver or plugins should be reported to
their respective projects; this repository will pick up fixes by pinning a newer
commit.
