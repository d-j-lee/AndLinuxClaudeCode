# shellcheck shell=bash
# andlinux restore FILE [--yes] : replace the container with a backup.

cmd_restore() {
  local file="" yes=0 answer
  while (($#)); do
    case $1 in
      --yes | -y) yes=1 ;;
      *) file=$1 ;;
    esac
    shift
  done
  [[ -f "$file" ]] || al_die "usage: andlinux restore FILE [--yes]"
  if ((!yes)); then
    [[ -t 0 ]] || al_die "refusing to overwrite '$AL_CONTAINER' without a terminal; pass --yes"
    read -r -p "This replaces container '$AL_CONTAINER' with $file. Type the container name to confirm: " answer
    [[ "$answer" == "$AL_CONTAINER" ]] || al_die "aborted"
  fi
  proot-distro kill "$AL_CONTAINER" >/dev/null 2>&1 || true
  rm -f "$AL_STATE_DIR"/run/*.pid
  al_step "restoring from $file"
  proot-distro restore "$file"
  al_ok "restored; run 'andlinux doctor' to check it"
}
