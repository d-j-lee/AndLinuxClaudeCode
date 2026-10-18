# AndLinux — guidance for Claude sessions working on this repository

Environment-as-code that installs an Ubuntu LTS desktop + Claude Code on Android
(Termux + proot-distro). Users and docs are Korean; code, comments and commit
messages are English.

## Map

- `install.sh` → `bin/andlinux` (dispatcher) → `lib/cmd/<command>.sh` (Termux side)
- `guest/provision.sh` → `guest/modules/<module>.sh` (Ubuntu side, runs as root)
- `config/defaults.env` is the single source of settings and their documentation
- `docs/` core docs (keep them current and final-quality), `docs/decisions/` ADRs
  (append-only history), `CHANGELOG.md` (history)

## Invariants

1. **Idempotent**: every step checks state before changing it. User files are
   created only if missing (`g_user_file`) or edited inside a managed block
   (`al_write_managed_block`). Rerunning `andlinux setup` must converge.
2. **Official channels only** (ADR 0004). New software → its vendor's apt repo via
   `g_add_apt_repo`, never curl-to-/usr/local binaries or random PPAs. No snaps.
3. **One environment for all sessions**: shell env goes in
   `guest/files/profile.sh` only (sourced by login shells and, via the top of
   `/etc/bash.bashrc`, by non-interactive bash/SSH).
4. **proot limits are real**: no systemd, Docker, namespaces, FUSE, ports < 1024.
   Long-running processes go through `andlinux svc` + `guest/bin/andlinux-svc`.
   OpenSSH sshd crashes proot (ADR 0003).
5. **Facts need sources**: version/compatibility claims in docs or ADRs come from
   measurement or primary sources. Mark anything unverified as such.

## Verify before pushing

```bash
shellcheck -x install.sh bin/andlinux lib/*.sh lib/cmd/*.sh guest/*.sh \
  guest/modules/*.sh guest/bin/* tests/*.sh && shellcheck -s sh guest/files/profile.sh
tests/e2e-termux.sh --profile cli            # needs Docker, ~6 min on x86_64
tests/e2e-termux.sh --profile desktop        # + XFCE/Xvfb checks, ~15 min
tests/guest-docker.sh --arch arm64 --profile cli   # arm64 packages (QEMU if not native)
```

Behind a TLS-inspecting proxy set `E2E_CA_FILE=<ca.pem>` (and `HTTPS_PROXY`).
Docker Hub rate limits are expected; setup falls back to Canonical's ubuntu-base.

## When changing things

- New module: see docs/architecture.md "모듈 추가하기"; add checks to
  `tests/guest-checks.sh`.
- New setting: add it with a comment to `config/defaults.env`; never read an
  `AL_*` variable that has no default there.
- Behaviour change visible to users: update the matching doc section in the same
  commit; add an ADR when an alternative was seriously considered.
