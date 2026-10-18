# shellcheck shell=bash
# andlinux ssh-key add <pubkey|file> | list
# Authorise public keys for SSH into the Ubuntu guest (password logins are off).

cmd_ssh_key() {
  local action=${1:-list} arg=${2:-} key
  al_require_container
  case $action in
    list)
      al_login -- bash -c 'cat ~/.ssh/authorized_keys 2>/dev/null || true'
      ;;
    add)
      [[ -n "$arg" ]] || al_die "usage: andlinux ssh-key add <pubkey|file>"
      if [[ -f "$arg" ]]; then key=$(<"$arg"); else key=$arg; fi
      key=$(printf '%s\n' "$key" | grep -E '^(ssh-(ed25519|rsa)|ecdsa-sha2-|sk-)' | head -n1)
      [[ -n "$key" ]] || al_die "that does not look like an SSH public key"
      # shellcheck disable=SC2016 # expanded by the guest shell
      al_login -- bash -c '
        set -e
        install -d -m 0700 ~/.ssh
        touch ~/.ssh/authorized_keys
        chmod 0600 ~/.ssh/authorized_keys
        grep -qxF "$1" ~/.ssh/authorized_keys || printf "%s\n" "$1" >>~/.ssh/authorized_keys
      ' ssh-key "$key"
      al_ok "key added; start the server with: andlinux svc start ssh"
      ;;
    *) al_die "usage: andlinux ssh-key add <pubkey|file> | list" ;;
  esac
}
