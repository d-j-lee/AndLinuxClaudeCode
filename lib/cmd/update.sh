# shellcheck shell=bash
# andlinux update [--allow-major] [--no-self]
# Toolkit (git), Termux packages, Ubuntu packages, Claude Code and mise tools,
# each from its official channel. Major proot-distro upgrades can migrate
# containers irreversibly, so they wait for --allow-major (after a backup).

update_self() {
  local before after
  [[ -d "$AL_ROOT/.git" ]] || return 1
  al_step "toolkit"
  before=$(git -C "$AL_ROOT" rev-parse HEAD)
  if ! git -C "$AL_ROOT" pull --ff-only --quiet; then
    al_warn "could not fast-forward $AL_ROOT (local changes?); keeping the current version"
    return 1
  fi
  after=$(git -C "$AL_ROOT" rev-parse HEAD)
  [[ "$before" != "$after" ]]
}

update_termux() {
  local -a apt_opts=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
  local installed candidate
  al_step "Termux packages"
  al_pkg_update
  installed=$(al_proot_distro_version)
  candidate=$(apt-cache policy proot-distro | awk '/Candidate:/ {print $2}')
  if [[ -n "$candidate" && "${installed%%.*}" != "${candidate%%.*}" ]]; then
    if ((ALLOW_MAJOR)); then
      apt-mark unhold proot-distro >/dev/null
      al_warn "upgrading proot-distro $installed -> $candidate (major)"
    else
      apt-mark hold proot-distro >/dev/null
      al_warn "holding proot-distro $installed: $candidate is a new major version that may"
      al_warn "migrate containers for good. Run 'andlinux backup', then 'andlinux update --allow-major'."
    fi
  elif apt-mark showhold | grep -qx proot-distro; then
    apt-mark unhold proot-distro >/dev/null
  fi
  al_retry 3 apt-get "${apt_opts[@]}" full-upgrade
  apt-get -y autoremove >/dev/null 2>&1 || true
}

update_guest() {
  al_step "Ubuntu packages (official repositories)"
  al_login --root -- /usr/local/bin/andlinux-guest-update

  if [[ "$AL_CLAUDE_METHOD" == native ]]; then
    al_step "Claude Code"
    al_login -- bash -lc 'command -v claude >/dev/null && claude update' ||
      al_warn "claude update failed; it will retry on its own at next start"
  fi
  al_step "mise tools"
  al_login -- bash -lc 'command -v mise >/dev/null || exit 0; MISE_YES=1 mise upgrade && mise reshim' ||
    al_warn "mise upgrade failed"
}

cmd_update() {
  ALLOW_MAJOR=0
  local self=1
  while (($#)); do
    case $1 in
      --allow-major) ALLOW_MAJOR=1 ;;
      --no-self) self=0 ;;
      *) al_die "unknown update option: $1" ;;
    esac
    shift
  done

  if ((self)) && update_self; then
    al_info "toolkit changed; continuing with the new version"
    local -a args=(--no-self)
    ((ALLOW_MAJOR)) && args+=(--allow-major)
    exec "$PREFIX/bin/bash" "$AL_ROOT/bin/andlinux" update "${args[@]}"
  fi
  update_termux
  al_require_container
  # Apply toolkit changes and new defaults; cheap when nothing changed.
  source "$AL_ROOT/lib/cmd/setup.sh"
  setup_guest
  update_guest
  al_ok "everything is up to date"
}
