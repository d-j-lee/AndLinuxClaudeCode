#!/usr/bin/env bash
# End-to-end test: install AndLinux inside the official Termux Docker image
# (termux/termux-docker, real Termux userland and packages) and check the
# result. proot needs ptrace, so the image must match the host CPU: x86_64 on
# CI runners. That covers everything except the Android kernel/SELinux and
# the Termux:X11 app itself (the desktop is checked on Xvfb instead).
#
#   tests/e2e-termux.sh [--profile cli|desktop|full] [--release 24.04|26.04]
#                       [--fallback] [--keep]
#
# --fallback points AL_IMAGE at a non-existent image so setup has to take the
# Canonical ubuntu-base tarball path (what happens when Docker Hub is down or
# rate-limits).
#
# Environment: E2E_CA_FILE   extra root CA for a TLS-inspecting proxy
#              HTTPS_PROXY   forwarded into Termux and the guest
#              E2E_ARTIFACTS directory for logs and the desktop screenshot
set -Eeuo pipefail

PROFILE=cli RELEASE=24.04 KEEP=0 FALLBACK=0
while (($#)); do
  case $1 in
    --profile) PROFILE=$2; shift ;;
    --release) RELEASE=$2; shift ;;
    --keep) KEEP=1 ;;
    --fallback) FALLBACK=1 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARTIFACTS=${E2E_ARTIFACTS:-$ROOT/tests/artifacts}
NAME=andlinux-e2e-$PROFILE-${RELEASE//./}
((FALLBACK)) && NAME+=-fallback
TX_HOME=/data/data/com.termux/files/home
TX_PREFIX=/data/data/com.termux/files/usr
mkdir -p "$ARTIFACTS"

log() { printf '\n\e[1;34m### %s\e[0m\n' "$*" >&2; }
fail() { printf '\e[1;31mFAIL: %s\e[0m\n' "$*" >&2; exit 1; }

# tx CMD : run CMD in a Termux login-like environment as the app user.
tx() {
  local -a env=(-e "HOME=$TX_HOME" -e "PREFIX=$TX_PREFIX" -e "TMPDIR=$TX_PREFIX/tmp"
    -e "PATH=$TX_PREFIX/bin" -e LANG=en_US.UTF-8 -e TERM=xterm-256color
    -e ANDROID_DATA=/data -e ANDROID_ROOT=/system -e NO_COLOR=1)
  local v
  for v in HTTPS_PROXY https_proxy NO_PROXY no_proxy; do
    [[ -n "${!v:-}" ]] && env+=(-e "$v=${!v}")
  done
  docker exec -i -u system -w "$TX_HOME" "${env[@]}" "$NAME" "$TX_PREFIX/bin/bash" -c "$1"
}

cleanup() {
  if ((KEEP)); then
    echo "kept container $NAME (docker rm -f $NAME)" >&2
  else
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log "start $NAME (termux/termux-docker:x86_64)"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --network host --security-opt seccomp=unconfined \
  termux/termux-docker:x86_64 sleep infinity >/dev/null
tx 'true' >/dev/null 2>&1 # finishes the bootstrap second stage
docker cp "$ROOT" "$NAME:$TX_HOME/AndLinuxClaudeCode"
docker exec "$NAME" chown -R system:system "$TX_HOME/AndLinuxClaudeCode"

config="AL_PROFILE=$PROFILE
AL_UBUNTU_RELEASE=$RELEASE"
if [[ -n "${E2E_CA_FILE:-}" ]]; then
  docker cp "$E2E_CA_FILE" "$NAME:$TX_HOME/extra-ca.pem"
  docker exec "$NAME" sh -c "chown system:system $TX_HOME/extra-ca.pem && cat $TX_HOME/extra-ca.pem >> $TX_PREFIX/etc/tls/cert.pem"
  config+="
AL_EXTRA_CA_FILE=$TX_HOME/extra-ca.pem
AL_APT_HTTPS=1"
fi
if ((FALLBACK)); then
  config+="
AL_IMAGE=andlinux-e2e/does-not-exist:$RELEASE"
fi
tx "mkdir -p ~/.config/andlinux && printf '%s\n' '$config' > ~/.config/andlinux/config.env"

log "install.sh (first run)"
start=$SECONDS
tx 'bash ~/AndLinuxClaudeCode/install.sh' 2>&1 | tee "$ARTIFACTS/$NAME-setup1.log" | tail -n 40
((PIPESTATUS[0] == 0)) || fail "first setup failed"
first=$((SECONDS - start))
if ((FALLBACK)); then
  grep -q "using Canonical's ubuntu-base tarball" "$ARTIFACTS/$NAME-setup1.log" || fail "fallback path not taken"
fi

log "setup again (must be idempotent)"
start=$SECONDS
tx 'andlinux setup' >"$ARTIFACTS/$NAME-setup2.log" 2>&1 || {
  tail -n 40 "$ARTIFACTS/$NAME-setup2.log"
  fail "second setup failed"
}
second=$((SECONDS - start))
echo "setup: first ${first}s, second ${second}s" >&2

log "guest checks"
tx "andlinux run bash ~/AndLinuxClaudeCode/tests/guest-checks.sh $RELEASE" | tee "$ARTIFACTS/$NAME-guest.log"
grep -q GUEST_OK "$ARTIFACTS/$NAME-guest.log" || fail "guest checks"

log "non-interactive SSH session sees the same environment"
# shellcheck disable=SC2016 # expanded by the Termux shell
tx 'set -e
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519
  andlinux ssh-key add ~/.ssh/id_ed25519.pub
  andlinux svc start ssh
  o="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p 2222"
  ssh $o dev@127.0.0.1 "id -un; claude --version; node --version; echo SSH_OK"
  # What VS Code Remote-SSH does: run its server in the guest, reach it
  # through an SSH local forward. ($HOME expands here: the Termux home is
  # visible at the same path inside the guest.)
  ssh $o dev@127.0.0.1 "bash $HOME/AndLinuxClaudeCode/tests/vscode-server-check.sh start 8765"
  ssh $o -M -S "$TMPDIR/e2e-fwd.sock" -f -N -L 18765:127.0.0.1:8765 dev@127.0.0.1
  sleep 2
  curl --noproxy "*" -fsS -o /dev/null http://127.0.0.1:18765/version && echo FORWARD_OK
  ssh -S "$TMPDIR/e2e-fwd.sock" -O exit dev@127.0.0.1 2>/dev/null || true
  ssh $o dev@127.0.0.1 "bash $HOME/AndLinuxClaudeCode/tests/vscode-server-check.sh stop"
  andlinux svc status ssh
  andlinux svc stop ssh' | tee "$ARTIFACTS/$NAME-ssh.log"
for m in SSH_OK VSCODE_SERVER_UP FORWARD_OK; do
  grep -q "$m" "$ARTIFACTS/$NAME-ssh.log" || fail "ssh: $m missing"
done

if [[ "$PROFILE" != cli ]]; then
  log "desktop session on Xvfb (stands in for Termux:X11)"
  tx 'andlinux root -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -q xvfb imagemagick xdotool >/dev/null"'
  tx 'andlinux run bash ~/AndLinuxClaudeCode/tests/guest-desktop-checks.sh' | tee "$ARTIFACTS/$NAME-desktop.log"
  docker cp "$NAME:$TX_PREFIX/tmp/andlinux-desktop.png" "$ARTIFACTS/$NAME-desktop.png" 2>/dev/null || true
  for m in PANEL_OK DESKTOP_OK FCITX_OK CODE_WINDOW_OK FIREFOX_WINDOW_OK TERMINAL_WINDOW_OK; do
    grep -q "$m" "$ARTIFACTS/$NAME-desktop.log" || fail "desktop: $m missing"
  done
fi

log "doctor"
tx 'andlinux doctor' | tee "$ARTIFACTS/$NAME-doctor.log" || true
grep -q 'Summary: 0 failure' "$ARTIFACTS/$NAME-doctor.log" || fail "doctor reported failures"

log "backup"
tx 'andlinux config set AL_BACKUP_DIR ~/backups && andlinux backup && ls -la ~/backups' |
  tee "$ARTIFACTS/$NAME-backup.log"
grep -qE 'andlinux-[0-9-]+\.tar\.(gz|zst)$' "$ARTIFACTS/$NAME-backup.log" || fail "backup"

echo -e "\n\e[1;32mE2E PASSED ($PROFILE, Ubuntu $RELEASE): setup ${first}s, rerun ${second}s\e[0m" >&2
