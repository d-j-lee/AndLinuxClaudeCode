#!/usr/bin/env bash
# Run the guest provisioning in a plain Ubuntu container for a given CPU
# architecture (no Termux, no proot). This proves that every package, vendor
# repository and installer exists for arm64 — what phones run — either on a
# native arm64 CI runner or locally through QEMU binfmt emulation.
#
#   tests/guest-docker.sh [--arch arm64|amd64] [--release 24.04] [--profile cli|desktop|full]
#
# Environment: E2E_CA_FILE      extra root CA for a TLS-inspecting proxy.
#              E2E_SKIP_MODULES modules to leave out (e.g. when a sandbox blocks
#                               github.com release downloads: code-server).
set -Eeuo pipefail

ARCH=arm64 RELEASE=24.04 PROFILE=desktop
while (($#)); do
  case $1 in
    --arch) ARCH=$2; shift ;;
    --release) RELEASE=$2; shift ;;
    --profile) PROFILE=$2; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=andlinux-guest-$ARCH-${RELEASE//./}-$PROFILE
cfg=$(mktemp)
trap 'rm -f "$cfg"; docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

# Same values the Termux side would write: defaults.env + test overrides.
(
  # shellcheck source=../lib/common.sh
  source "$ROOT/lib/common.sh"
  al_load_env "$ROOT/config/defaults.env"
  # shellcheck disable=SC2034 # read through compgen below
  AL_PROFILE=$PROFILE AL_UBUNTU_RELEASE=$RELEASE AL_TZ=Asia/Seoul AL_ANDROID_DOWNLOADS='' \
    AL_MODULES_SKIP=${E2E_SKIP_MODULES:-}
  compgen -v AL_ | while IFS= read -r v; do printf '%s=%q\n' "$v" "${!v}"; done
) >"$cfg"
docker_args=(--platform "linux/$ARCH" --name "$NAME" -v "$ROOT:/src:ro" -v "$cfg:/cfg.env:ro")
if [[ -n "${E2E_CA_FILE:-}" ]]; then
  docker_args+=(-v "$E2E_CA_FILE:/extra-ca.pem:ro" --network host -e "HTTPS_PROXY=${HTTPS_PROXY:-}" -e "https_proxy=${HTTPS_PROXY:-}")
  printf 'AL_EXTRA_CA_FILE=/extra-ca.pem\nAL_APT_HTTPS=1\n' >>"$cfg"
fi

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run "${docker_args[@]}" "ubuntu:$RELEASE" bash -c '
  set -e
  uname -m
  AL_CONFIG_FILE=/cfg.env bash /src/guest/provision.sh
  su - dev -c "bash /src/tests/guest-checks.sh '"$RELEASE"'"
'
echo "GUEST PROVISION PASSED ($ARCH, Ubuntu $RELEASE, $PROFILE)"
