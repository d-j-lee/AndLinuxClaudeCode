# shellcheck shell=bash
# andlinux config [show|edit|path|set KEY VALUE]

cmd_config() {
  case ${1:-show} in
    show)
      compgen -v AL_ | grep -vE '^AL_(ROOT|CONFIG_DIR|STATE_DIR|USER_CONFIG|GUEST_CONFIG)$' |
        sort | while IFS= read -r var; do printf '%s=%q\n' "$var" "${!var}"; done
      ;;
    path) printf '%s\n' "$AL_USER_CONFIG" ;;
    edit)
      mkdir -p "$AL_CONFIG_DIR"
      if [[ ! -f "$AL_USER_CONFIG" ]]; then
        {
          echo "# AndLinux overrides. Defaults and documentation:"
          echo "#   $AL_ROOT/config/defaults.env"
          echo "# Apply changes with: andlinux setup"
        } >"$AL_USER_CONFIG"
      fi
      "${EDITOR:-nano}" "$AL_USER_CONFIG"
      ;;
    set)
      (($# == 3)) || al_die "usage: andlinux config set KEY VALUE"
      al_config_set "$2" "$3"
      al_ok "$2 saved; apply with: andlinux setup"
      ;;
    *) al_die "usage: andlinux config [show|edit|path|set KEY VALUE]" ;;
  esac
}
