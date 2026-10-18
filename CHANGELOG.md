# Changelog

## Unreleased

First version.

- `install.sh` one-line installer for Termux; `andlinux` CLI: setup, update,
  doctor, config, shell/root/run/claude, desktop/stop, svc, ssh-key, ip, tunnel,
  backup/restore.
- Ubuntu 24.04 LTS guest (26.04 optional) via proot-distro 5.x, with fallback to
  Canonical's ubuntu-base tarball when Docker Hub is unavailable.
- Profiles `cli`, `desktop` (default), `full`; modules base, user, bridge,
  devtools, claude, ssh, desktop, korean, browser, vscode, code-server, chrome,
  hosting, toolchains.
- Claude Code through the official native installer (or official apt), with a
  user-level CLAUDE.md describing the environment.
- Dropbear SSH service for VS Code Remote-SSH / scp / rsync from a PC.
- Corporate proxy support: proxy variables forwarded, `AL_EXTRA_CA_FILE`.
- Resilience: broken Termux mirror -> official default mirror; Docker Hub
  failure -> Canonical ubuntu-base (SHA256-checked); apt/pkg watchdogs for
  stalled connections.
- Tests: end-to-end in the official Termux Docker image (incl. VS Code server
  over an SSH forward, Xvfb desktop checks, fallback path), guest provisioning
  in plain containers (arm64 in CI), CI workflow.
