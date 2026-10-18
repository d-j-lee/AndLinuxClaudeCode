# shellcheck shell=bash
# andlinux setup [--profile P] [--guest-only] [--modules "m1 m2"]
# Converge Termux packages, the Ubuntu container and the guest provisioning.
# Every step checks state first, so rerunning is safe and cheap.

setup_preflight() {
  local arch rel sdk free_gb mem_gb need_gb=8
  al_step "preflight"
  arch=$(uname -m)
  case $arch in
    aarch64) ;;
    x86_64) al_warn "x86_64 host: fine for emulators and CI; phones are aarch64" ;;
    *) al_die "unsupported CPU '$arch': Claude Code needs a 64-bit ARM (aarch64) device" ;;
  esac
  case ${TERMUX_APK_RELEASE:-} in
    GOOGLE_PLAY*)
      al_warn "Google Play build of Termux: it is a separate, experimental product"
      al_warn "without the Termux:API app. Prefer F-Droid or GitHub (docs/setup-guide.md)."
      ;;
  esac
  rel=$(al_android_prop ro.build.version.release)
  sdk=$(al_android_prop ro.build.version.sdk)
  [[ -n "$rel" ]] && al_info "Android $rel (SDK $sdk), $(al_android_prop ro.product.manufacturer) $(al_android_prop ro.product.model)"
  al_info "Termux ${TERMUX_VERSION:-?} (${TERMUX_APK_RELEASE:-unknown build}), profile '$AL_PROFILE', Ubuntu $AL_UBUNTU_RELEASE"

  [[ "$AL_PROFILE" == cli ]] && need_gb=4
  free_gb=$(df -Pk "$PREFIX" | awk 'NR==2 {printf "%d", $4 / 1048576}')
  if ((free_gb < need_gb)); then
    al_warn "only ${free_gb} GB free; profile '$AL_PROFILE' needs about ${need_gb} GB"
  fi
  mem_gb=$(awk '/^MemTotal:/ {printf "%d", ($2 / 1048576) + 0.5}' /proc/meminfo)
  if ((mem_gb < 4)); then
    al_warn "${mem_gb} GB RAM: Claude Code asks for 4 GB or more"
  fi
}

setup_termux_packages() {
  local -a pkgs=(proot-distro git curl openssh termux-api termux-tools)
  local -a apt_opts=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
  al_step "Termux packages"
  al_pkg_update
  # Termux is a rolling distribution: partial upgrades break shared libraries.
  al_retry 3 apt-get "${apt_opts[@]}" full-upgrade
  if [[ "$AL_PROFILE" != cli ]]; then
    dpkg -s x11-repo >/dev/null 2>&1 || { al_retry 3 pkg install -y x11-repo && al_pkg_update; }
    pkgs+=(termux-x11-nightly pulseaudio)
    [[ "$AL_GPU" == virgl ]] && pkgs+=(virglrenderer-android)
  fi
  [[ -n "${AL_BACKUP_RCLONE_REMOTE:-}" ]] && pkgs+=(rclone)
  al_retry 3 pkg install -y "${pkgs[@]}"

  local pd proot
  pd=$(al_proot_distro_version)
  proot=$(dpkg-query -W -f='${Version}' proot 2>/dev/null || true)
  al_version_ge "$pd" 5.0.0 || al_die "proot-distro $pd is too old (need 5.x)"
  if al_version_ge "$AL_UBUNTU_RELEASE" 25.10 && ! al_version_ge "$proot" 5.1.107.93; then
    al_die "Ubuntu $AL_UBUNTU_RELEASE needs Termux proot >= 5.1.107.93 (have $proot); run: pkg upgrade"
  fi
  al_ok "proot-distro $pd, proot $proot"
}

setup_storage() {
  al_step "shared storage"
  if [[ -r /storage/emulated/0 && -d "$HOME/storage" ]]; then
    al_ok "Termux can read shared storage"
    return 0
  fi
  if [[ -t 0 ]] && al_have termux-setup-storage; then
    al_info "Android will ask for storage access: tap Allow"
    termux-setup-storage || true
    local _
    for _ in $(seq 1 30); do
      [[ -r /storage/emulated/0 ]] && break
      sleep 2
    done
  fi
  if [[ -r /storage/emulated/0 ]]; then
    al_ok "Termux can read shared storage"
  else
    al_warn "no shared storage access: ~/Android and Android-visible downloads stay off"
    al_warn "run 'termux-setup-storage' and then 'andlinux setup' again"
  fi
}

# Canonical's ubuntu-base tarball for the release (latest point release).
setup_ubuntu_base() {
  local arch base index file dest
  case $(uname -m) in
    aarch64) arch=arm64 ;;
    x86_64) arch=amd64 ;;
    *) return 1 ;;
  esac
  base=https://cdimage.ubuntu.com/ubuntu-base/releases/$AL_UBUNTU_RELEASE/release
  index=$(curl -fsSL "$base/") || return 1
  file=$(grep -oE "ubuntu-base-${AL_UBUNTU_RELEASE//./\\.}(\\.[0-9]+)?-base-${arch}\\.tar\\.gz" <<<"$index" |
    sort -uV | tail -n1)
  [[ -n "$file" ]] || return 1
  dest=$AL_STATE_DIR/cache/$file
  mkdir -p "${dest%/*}"
  al_info "downloading $base/$file"
  al_retry 3 curl -fL --progress-bar -o "$dest.part" "$base/$file" || return 1
  mv "$dest.part" "$dest"
  # SHA256SUMS comes from the same HTTPS host; it guards against corruption.
  if ! curl -fsSL "$base/SHA256SUMS" | grep " \*\?${file}\$" |
    (cd "${dest%/*}" && sha256sum -c --status -); then
    rm -f "$dest"
    al_err "checksum mismatch for $file"
    return 1
  fi
  printf '%s\n' "$dest"
}

setup_container() {
  al_step "Ubuntu container '$AL_CONTAINER'"
  if al_container_exists; then
    al_ok "already installed"
    return 0
  fi
  al_info "installing $AL_IMAGE"
  if al_retry 2 proot-distro install -n "$AL_CONTAINER" "$AL_IMAGE"; then
    return 0
  fi
  [[ "$AL_IMAGE_FALLBACK" == ubuntu-base ]] || al_die "could not install $AL_IMAGE"
  al_warn "registry install failed (offline or rate-limited); using Canonical's ubuntu-base tarball"
  local tarball
  tarball=$(setup_ubuntu_base) || al_die "could not fetch ubuntu-base $AL_UBUNTU_RELEASE"
  proot-distro install -n "$AL_CONTAINER" "$tarball"
  rm -f "$tarball"
}

setup_guest() {
  al_write_guest_config
  al_step "Ubuntu guest provisioning"
  al_login --root -e "AL_CONFIG_FILE=$AL_GUEST_CONFIG" -- \
    bash "$AL_ROOT/guest/provision.sh" "$@"
}

setup_shortcuts() {
  # Termux:Widget home-screen shortcuts (harmless without the widget app).
  local dir=$HOME/.shortcuts
  mkdir -p "$dir"
  printf '#!%s/bin/bash\nexec andlinux shell\n' "$PREFIX" >"$dir/AndLinux Shell"
  printf '#!%s/bin/bash\nexec andlinux claude\n' "$PREFIX" >"$dir/Claude Code"
  if [[ "$AL_PROFILE" != cli ]]; then
    printf '#!%s/bin/bash\nexec andlinux desktop\n' "$PREFIX" >"$dir/AndLinux Desktop"
  fi
  chmod 0755 "$dir"/*
  # Termux:Boot autostart of selected services.
  if [[ -n "${AL_BOOT_SERVICES:-}" ]]; then
    mkdir -p "$HOME/.termux/boot"
    printf '#!%s/bin/bash\ntermux-wake-lock\nexec andlinux svc start %s\n' \
      "$PREFIX" "$AL_BOOT_SERVICES" >"$HOME/.termux/boot/50-andlinux"
    chmod 0755 "$HOME/.termux/boot/50-andlinux"
  else
    rm -f "$HOME/.termux/boot/50-andlinux"
  fi
}

setup_summary() {
  local x11=""
  [[ "$AL_PROFILE" != cli ]] && x11="
  Desktop:       andlinux desktop   (install the Termux:X11 app first, see below)"
  cat >&2 <<EOF

AndLinux is ready (profile '$AL_PROFILE', container '$AL_CONTAINER', user '$AL_USER').

  Shell:         andlinux            (or: andlinux shell)
  Claude Code:   andlinux claude     (first run asks you to log in)$x11
  SSH from a PC: andlinux ssh-key add ~/id.pub && andlinux svc start ssh
  Health check:  andlinux doctor     Update everything: andlinux update

One-time Android settings (docs/setup-guide.md):
  1. Developer options > "Disable child process restrictions" (Android 14+), or
     adb shell settings put global settings_enable_monitor_phantom_procs false
  2. Settings > Apps > Termux > Battery > Unrestricted
  3. Termux:X11 app: termux-x11-universal-debug.apk from
     https://github.com/termux/termux-x11/releases/tag/nightly
EOF
}

cmd_setup() {
  local guest_only=0 modules=""
  while (($#)); do
    case $1 in
      --profile)
        [[ -n "${2:-}" ]] || al_die "--profile needs cli|desktop|full"
        al_config_set AL_PROFILE "$2"
        shift
        ;;
      --guest-only) guest_only=1 ;;
      --modules)
        modules=${2:-}
        guest_only=1
        shift
        ;;
      *) al_die "unknown setup option: $1" ;;
    esac
    shift
  done

  local log
  mkdir -p "$AL_STATE_DIR/logs"
  log=$AL_STATE_DIR/logs/setup-$(date +%Y%m%d-%H%M%S).log
  exec > >(tee -a "$log") 2>&1
  al_info "log: $log"

  if ((!guest_only)); then
    setup_preflight
    setup_termux_packages
    setup_storage
    setup_container
  else
    al_require_container
  fi
  # shellcheck disable=SC2086 # module list is word-split on purpose
  setup_guest $modules
  ((guest_only)) && return 0
  setup_shortcuts
  setup_summary
}
