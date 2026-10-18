#!/usr/bin/env bash
# Provision the Ubuntu guest. Runs as root inside the container, started by
# `andlinux setup` on the Termux side:
#
#   AL_CONFIG_FILE=<guest-config.env> bash guest/provision.sh [MODULE...]
#
# With no MODULE arguments, the modules of $AL_PROFILE run in order.
set -Eeuo pipefail

AL_GUEST_SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export AL_GUEST_SRC
# shellcheck source=../lib/common.sh
source "$AL_GUEST_SRC/../lib/common.sh"
# shellcheck source=lib.sh
source "$AL_GUEST_SRC/lib.sh"

[[ "$(id -u)" == 0 ]] || al_die "provision.sh must run as root inside the guest"
[[ -n "${AL_CONFIG_FILE:-}" ]] || al_die "AL_CONFIG_FILE is not set"
al_load_env "$AL_CONFIG_FILE"
# The target locale may not exist yet; C.UTF-8 always does (no perl warnings).
export LANG=C.UTF-8 LC_ALL=C.UTF-8

# Canonical module order; profiles select a prefix-free subset of it.
G_ALL_MODULES="base user bridge devtools claude ssh desktop korean browser vscode code-server chrome hosting toolchains"
declare -A G_PROFILE=(
  [cli]="base user bridge devtools claude ssh"
  [desktop]="base user bridge devtools claude ssh desktop korean browser vscode"
  [full]="$G_ALL_MODULES"
)

g_resolve_modules() {
  local wanted=${G_PROFILE[$AL_PROFILE]:-} m out=()
  [[ -n "$wanted" ]] || al_die "unknown AL_PROFILE '$AL_PROFILE' (cli|desktop|full)"
  wanted="$wanted ${AL_MODULES_EXTRA:-}"
  for m in $G_ALL_MODULES; do
    al_word_in "$m" "$wanted" || continue
    al_word_in "$m" "${AL_MODULES_SKIP:-}" && continue
    out+=("$m")
  done
  printf '%s\n' "${out[@]}"
}

g_install_runtime() {
  # Keep a copy of the guest helpers and the config inside the rootfs, so the
  # guest keeps working even if the Termux checkout moves.
  install -d -m 0755 /etc/andlinux /usr/local/lib/andlinux
  install -m 0644 "$AL_CONFIG_FILE" /etc/andlinux/config.env
  install -m 0644 "$AL_GUEST_SRC/../lib/common.sh" /usr/local/lib/andlinux/common.sh
  local f var
  for f in "$AL_GUEST_SRC"/bin/*; do
    install -m 0755 "$f" "/usr/local/bin/$(basename "$f")"
  done
  # Termux:API helpers start Android's app_process, which needs the Android
  # runtime variables. `andlinux` sessions forward them; SSH sessions do not,
  # so keep a copy for the android-* helpers to fall back on.
  {
    echo "# Captured from Termux by andlinux setup."
    for var in ANDROID_ART_ROOT ANDROID_DATA ANDROID_I18N_ROOT ANDROID_ROOT \
      ANDROID_RUNTIME_ROOT ANDROID_TZDATA_ROOT BOOTCLASSPATH \
      DEX2OATBOOTCLASSPATH SYSTEMSERVERCLASSPATH EXTERNAL_STORAGE \
      TERMUX_PREFIX TERMUX_HOME; do
      if [[ -n "${!var:-}" ]]; then
        printf 'export %s=%q\n' "$var" "${!var}"
      fi
    done
  } >/etc/andlinux/android.env
}

main() {
  local -a modules
  local explicit=0
  if (($#)); then
    modules=("$@")
    explicit=1
  else
    mapfile -t modules < <(g_resolve_modules)
  fi
  al_step "guest: Ubuntu ${G_RELEASE} (${G_CODENAME}, ${G_ARCH}), profile '${AL_PROFILE}'"
  al_info "modules: ${modules[*]}"
  g_install_runtime

  local m started
  for m in "${modules[@]}"; do
    [[ -f "$AL_GUEST_SRC/modules/$m.sh" ]] || al_die "no such module: $m"
    al_step "module: $m"
    started=$SECONDS
    # shellcheck source=/dev/null
    source "$AL_GUEST_SRC/modules/$m.sh"
    "mod_${m//-/_}"
    al_ok "$m ($((SECONDS - started))s)"
  done
  # The Docker image deletes downloaded .debs (docker-clean); the ubuntu-base
  # tarball does not. Keep both paths equally small on phone storage.
  apt-get clean

  ((explicit)) && return 0
  {
    echo "provisioned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "profile=$AL_PROFILE"
    echo "modules=${modules[*]}"
    echo "toolkit=$(git -C "$AL_GUEST_SRC/.." describe --tags --always --dirty 2>/dev/null || echo unknown)"
  } >/etc/andlinux/provisioned
}

main "$@"
