# shellcheck shell=bash
# Non-root developer account with passwordless sudo and a shell environment
# that works the same in the desktop, the CLI, SSH and Claude Code's Bash tool.

mod_user() {
  local home grp
  [[ "$AL_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || al_die "invalid AL_USER '$AL_USER'"
  if ! id "$AL_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "AndLinux developer" "$AL_USER"
    al_info "created user $AL_USER"
  fi
  for grp in sudo audio video plugdev; do
    getent group "$grp" >/dev/null && usermod -aG "$grp" "$AL_USER"
  done
  # Under proot every process runs as the Termux app UID; sudo is a
  # convenience, not a security boundary (docs/architecture.md#보안-모델).
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$AL_USER" >/etc/sudoers.d/90-andlinux
  chmod 0440 /etc/sudoers.d/90-andlinux
  visudo -cq -f /etc/sudoers.d/90-andlinux

  g_template profile.sh >/etc/profile.d/andlinux.sh
  chmod 0644 /etc/profile.d/andlinux.sh
  # Non-interactive bash (ssh commands, IDE remotes) reads bash.bashrc but
  # Ubuntu's copy returns early, so the hook has to sit at the very top.
  al_write_managed_block /etc/bash.bashrc andlinux \
    '[ -r /etc/profile.d/andlinux.sh ] && . /etc/profile.d/andlinux.sh' top

  home=$(g_user_home)
  g_user_dir "$home/projects" "$home/.local/bin" "$home/.local/share" \
    "$home/.local/state" "$home/.config" "$home/.cache"
}
