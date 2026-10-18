# shellcheck shell=bash
# andlinux doctor : read-only health report of device, Termux and the guest.

_dr_pass() { printf '  \e[32mPASS\e[0m %s\n' "$*"; }
_dr_warn() { printf '  \e[33mWARN\e[0m %s\n' "$*"; DR_WARN=$((DR_WARN + 1)); }
_dr_fail() { printf '  \e[31mFAIL\e[0m %s\n' "$*"; DR_FAIL=$((DR_FAIL + 1)); }
_dr_info() { printf '  INFO %s\n' "$*"; }

doctor_device() {
  local rel sdk arch phantom page hyp
  echo "Device"
  arch=$(uname -m)
  rel=$(al_android_prop ro.build.version.release)
  sdk=$(al_android_prop ro.build.version.sdk)
  page=$(getconf PAGESIZE 2>/dev/null || echo '?')
  if [[ "$arch" == aarch64 ]]; then _dr_pass "CPU $arch"; else _dr_warn "CPU $arch (phones are aarch64)"; fi
  if [[ -n "$rel" ]]; then
    _dr_info "Android $rel (SDK $sdk), $(al_android_prop ro.product.manufacturer) $(al_android_prop ro.product.model), page size $page"
  else
    _dr_info "not running on Android (no getprop); page size $page"
  fi
  phantom=$(timeout 5 /system/bin/settings get global settings_enable_monitor_phantom_procs 2>/dev/null || true)
  case $phantom in
    false) _dr_pass "phantom process killer disabled" ;;
    true | null | "")
      if [[ -n "$sdk" ]] && ((sdk >= 31)); then
        _dr_warn "phantom process killer may kill the desktop (signal 9); see docs/setup-guide.md#2-안드로이드-설정-중요"
      fi
      ;;
  esac
  hyp=$(al_android_prop ro.boot.hypervisor.vm.supported)
  [[ "$hyp" == true ]] && _dr_info "this device can run Android's Linux Terminal VM (Docker workloads): docs/avf.md"
  local mem_gb free_gb
  mem_gb=$(awk '/^MemTotal:/ {printf "%.1f", $2 / 1048576}' /proc/meminfo)
  free_gb=$(df -Pk "$PREFIX" | awk 'NR==2 {printf "%.1f", $4 / 1048576}')
  _dr_info "RAM ${mem_gb} GB, free storage ${free_gb} GB"
}

doctor_termux() {
  local pd proot
  echo "Termux"
  case ${TERMUX_APK_RELEASE:-} in
    F_DROID | GITHUB) _dr_pass "Termux ${TERMUX_VERSION:-?} (${TERMUX_APK_RELEASE})" ;;
    GOOGLE_PLAY*) _dr_warn "Termux from Google Play: separate experimental build, no Termux:API app" ;;
    *) _dr_info "Termux ${TERMUX_VERSION:-?} (build ${TERMUX_APK_RELEASE:-unknown})" ;;
  esac
  pd=$(al_proot_distro_version)
  proot=$(dpkg-query -W -f='${Version}' proot 2>/dev/null || true)
  if [[ -z "$pd" ]]; then
    _dr_fail "proot-distro not installed (run: andlinux setup)"
  elif al_version_ge "$pd" 5.0.0; then
    _dr_pass "proot-distro $pd, proot $proot"
  else
    _dr_fail "proot-distro $pd is older than 5.x"
  fi
  apt-mark showhold 2>/dev/null | grep -qx proot-distro &&
    _dr_info "proot-distro is held (major upgrade pending): andlinux backup && andlinux update --allow-major"
  if [[ -r /storage/emulated/0 ]]; then
    _dr_pass "shared storage readable"
  else
    _dr_warn "no shared storage access (run termux-setup-storage)"
  fi
  if [[ "$AL_PROFILE" != cli ]]; then
    if al_have termux-x11; then
      _dr_pass "termux-x11 package installed (the Termux:X11 app is separate)"
    else
      _dr_fail "termux-x11-nightly missing"
    fi
  fi
  if al_have termux-battery-status && timeout 8 termux-battery-status >/dev/null 2>&1; then
    _dr_pass "Termux:API app responds"
  else
    _dr_info "Termux:API app not responding (needed for android-share / android-clip)"
  fi
}

doctor_guest() {
  local root ver
  echo "Ubuntu guest"
  if ! al_container_exists; then
    _dr_fail "container '$AL_CONTAINER' not installed (run: andlinux setup)"
    return
  fi
  root=$(al_rootfs)
  ver=$(. "$root/etc/os-release" && echo "$PRETTY_NAME")
  _dr_pass "container '$AL_CONTAINER': $ver"
  if [[ -f "$root/etc/andlinux/provisioned" ]]; then
    _dr_pass "provisioned: $(tr '\n' ' ' <"$root/etc/andlinux/provisioned")"
  else
    _dr_fail "guest not provisioned (run: andlinux setup)"
  fi
  if grep -q "^${AL_USER}:" "$root/etc/passwd"; then
    _dr_pass "user $AL_USER"
  else
    _dr_fail "user $AL_USER missing"
  fi
  local claude
  claude=$(al_login -- bash -lc 'claude --version' 2>/dev/null | tail -n1 || true)
  if [[ -n "$claude" ]]; then
    _dr_pass "Claude Code $claude"
  else
    _dr_fail "claude does not run in the guest"
  fi
  source "$AL_ROOT/lib/cmd/svc.sh"
  local s pid
  for s in $AL_SERVICES; do
    if pid=$(_svc_pid "$s"); then _dr_info "service $s running (session $pid)"; fi
  done
}

cmd_doctor() {
  DR_WARN=0 DR_FAIL=0
  doctor_device
  doctor_termux
  doctor_guest
  echo
  echo "Summary: $DR_FAIL failure(s), $DR_WARN warning(s)"
  ((DR_FAIL == 0))
}
