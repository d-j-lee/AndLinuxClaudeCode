#!/usr/bin/env bash
# shellcheck disable=SC2016 # the bash -c bodies expand inside the check
# Runs inside the guest as the dev user (tests/e2e-termux.sh): andlinux run bash THIS RELEASE
set -euo pipefail
release=$1
check() { printf '  %-44s' "$1"; shift; if out=$("$@" 2>&1); then echo "ok ${out%%$'\n'*}"; else echo "FAILED"; echo "$out" >&2; exit 1; fi; }

check "user is dev"                 test "$(id -un)" = dev
check "passwordless sudo"           bash -c 'sudo -n true 2>&1 | grep -v "audit message" >&2; exit "${PIPESTATUS[0]}"'
check "Ubuntu $release"             grep -q "^VERSION_ID=\"$release\"" /etc/os-release
check "claude"                      claude --version
check "node (mise)"                 node --version
check "uv (mise)"                   uv --version
check "gh (official repo)"          gh --version
check "mise"                        mise --version
check "git"                         git --version
check "LANG from /etc/default/locale" bash -c 'locale | grep -q "LANG=en_US.UTF-8"'
check "timezone"                    bash -c 'test "$(cat /etc/timezone)" = Asia/Seoul && date +%Z'
if [[ -d /data/data/com.termux/files/home ]]; then
  check "Termux home link"          test -L "$HOME/Termux"
fi
check "claude settings"             test -f "$HOME/.claude/settings.json"
check "claude CLAUDE.md block"      grep -q "andlinux >>>" "$HOME/.claude/CLAUDE.md"
check "android helpers"             command -v android-open android-share android-clip
check "PATH has mise shims"         bash -c 'case ":$PATH:" in *"/.local/share/mise/shims:"*) ;; *) exit 1;; esac'
check "npm global install"          bash -c 'npm install -g --silent cowsay@1 && cowsay ok >/dev/null'
check "python venv + uv pip"        bash -c 'cd "$(mktemp -d)" && uv venv -q && uv pip install -q six && .venv/bin/python -c "import six"'
check "C build"                     bash -c 'cd "$(mktemp -d)" && printf "int main(){return 0;}" > t.c && cc t.c -o t && ./t'
check "localhost server"            bash -c 'python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 & p=$!; sleep 2; curl --noproxy "*" -fsS -o /dev/null http://127.0.0.1:8765/; rc=$?; kill $p; exit $rc'
echo GUEST_OK
