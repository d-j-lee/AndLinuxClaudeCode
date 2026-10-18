# shellcheck shell=bash
# SSH server for the guest (VS Code Remote-SSH, scp/sftp, rsync from a PC).
# Dropbear instead of OpenSSH: OpenSSH's sshd-session trips a proot assertion
# (path.c compare_paths2) and kills the session (docs/decisions/0003-ssh.md).
# `andlinux svc start ssh` runs it; keys come from `andlinux ssh-key add`.

mod_ssh() {
  local home
  g_install dropbear-bin openssh-sftp-server
  install -d -m 0755 /etc/dropbear
  home=$(g_user_home)
  install -d -m 0700 -o "$AL_USER" -g "$AL_USER" "$home/.ssh"
  if [[ ! -e "$home/.ssh/authorized_keys" ]]; then
    install -m 0600 -o "$AL_USER" -g "$AL_USER" /dev/null "$home/.ssh/authorized_keys"
  fi
}
