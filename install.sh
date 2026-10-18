#!/usr/bin/env bash
# AndLinux installer. Run inside Termux (F-Droid or GitHub build):
#
#   curl -fsSL https://raw.githubusercontent.com/d-j-lee/AndLinuxClaudeCode/main/install.sh | bash
#
# or from a checkout:  bash install.sh [setup options]
#
# It installs git, puts the toolkit in ~/.andlinux (or uses this checkout),
# links the `andlinux` command into $PREFIX/bin and runs `andlinux setup`.
set -Eeuo pipefail

AL_REPO_URL=${AL_REPO_URL:-https://github.com/d-j-lee/AndLinuxClaudeCode.git}
AL_REF=${AL_REF:-main}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -n "${PREFIX:-}" && "$PREFIX" == */com.termux/files/usr ]] ||
  die "run this inside Termux (PREFIX=${PREFIX:-unset})"
[[ "$(id -u)" != 0 ]] || die "do not run as root; use the normal Termux shell"

# Prefer the checkout this script lives in, when there is one.
self=${BASH_SOURCE[0]:-}
if [[ -n "$self" && -f "$self" && -f "$(dirname "$self")/bin/andlinux" ]]; then
  AL_ROOT=$(cd "$(dirname "$self")" && pwd)
else
  AL_ROOT=${AL_ROOT:-$HOME/.andlinux}
fi

if ! command -v git >/dev/null 2>&1; then
  printf '==> installing git\n' >&2
  if ! pkg update -y; then
    # pkg picked a broken community mirror: pin the official default one
    # (what termux-change-repo does) and try again.
    if [[ -f "$PREFIX/etc/termux/mirrors/default" && ! -e "$PREFIX/etc/termux/chosen_mirrors" ]]; then
      printf 'warn: Termux mirror failed; switching to the official default mirror\n' >&2
      ln -sfn "$PREFIX/etc/termux/mirrors/default" "$PREFIX/etc/termux/chosen_mirrors"
    fi
    pkg --check-mirror update -y
  fi
  pkg install -y git
fi

if [[ ! -f "$AL_ROOT/bin/andlinux" ]]; then
  printf '==> cloning %s (%s) into %s\n' "$AL_REPO_URL" "$AL_REF" "$AL_ROOT" >&2
  git clone --depth 50 --branch "$AL_REF" "$AL_REPO_URL" "$AL_ROOT"
elif [[ -d "$AL_ROOT/.git" && "$AL_ROOT" == "$HOME/.andlinux" ]]; then
  git -C "$AL_ROOT" pull --ff-only || printf 'warn: could not fast-forward %s\n' "$AL_ROOT" >&2
fi

link=$PREFIX/bin/andlinux
cat >"$link" <<EOF
#!$PREFIX/bin/bash
exec "$PREFIX/bin/bash" "$AL_ROOT/bin/andlinux" "\$@"
EOF
chmod 0755 "$link"
printf '==> linked %s -> %s/bin/andlinux\n' "$link" "$AL_ROOT" >&2

# Piped installs have the script on stdin; give setup the terminal instead.
if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
  exec "$link" setup "$@" </dev/tty
fi
exec "$link" setup "$@"
