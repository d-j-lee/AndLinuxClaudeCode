# shellcheck shell=bash
# andlinux svc <start|stop|restart|status> [ssh|code-server|all]
# Long-running guest services as detached proot-distro sessions. There is no
# systemd under proot; this is the replacement for `systemctl`. Each service
# runs as `andlinux-svc NAME` (guest/bin) so it can be found by its command
# line even when the PID file is gone.

AL_SERVICES="ssh code-server"

_svc_pidfile() { printf '%s/run/%s.pid' "$AL_STATE_DIR" "$1"; }

# _svc_pid NAME : print the proot-distro session PID of a running service.
_svc_pid() {
  local name=$1 pidfile pid
  pidfile=$(_svc_pidfile "$name")
  if [[ -f "$pidfile" ]]; then
    pid=$(<"$pidfile")
    if proot-distro ps -q 2>/dev/null | grep -qx "$pid"; then
      printf '%s\n' "$pid"
      return 0
    fi
    rm -f "$pidfile"
  fi
  # Fallback: a session whose proot command line runs "andlinux-svc NAME"
  # inside this container (lost PID file, started from elsewhere, ...).
  for pid in $(proot-distro ps -q 2>/dev/null); do
    [[ -r "/proc/$pid/cmdline" ]] || continue
    # proot runs with --rootfs=. from inside the container directory.
    if tr '\0' '\n' <"/proc/$pid/cmdline" | grep -qx "andlinux-svc $name" &&
      [[ "$(readlink "/proc/$pid/cwd")" == */containers/"$AL_CONTAINER"/rootfs ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
  done
  return 1
}

_svc_check() {
  local root
  root=$(al_rootfs)
  [[ -x "$root/usr/local/bin/andlinux-svc" ]] || al_die "guest helpers missing; run 'andlinux setup'"
  case $1 in
    ssh)
      [[ -x "$root/usr/sbin/dropbear" ]] || al_die "ssh: dropbear missing; run 'andlinux setup'"
      [[ -s "$root/home/$AL_USER/.ssh/authorized_keys" ]] ||
        al_die "ssh: no authorised keys yet; run 'andlinux ssh-key add <pubkey or file>'"
      ;;
    code-server)
      [[ -x "$root/usr/bin/code-server" ]] ||
        al_die "code-server is not installed; run 'andlinux setup --profile full' or add AL_MODULES_EXTRA=code-server"
      ;;
    *) al_die "unknown service '$1' (ssh, code-server)" ;;
  esac
}

_svc_log() {
  case $1 in
    ssh) printf '%s/var/log/andlinux/ssh.log' "$(al_rootfs)" ;;
    code-server) printf '%s/home/%s/.local/state/code-server.log' "$(al_rootfs)" "$AL_USER" ;;
  esac
}

_svc_start() {
  local name=$1 out pid
  if pid=$(_svc_pid "$name"); then
    al_ok "$name already running (session $pid)"
    return 0
  fi
  _svc_check "$name"
  local -a as=()
  [[ "$name" == ssh ]] && as=(--root -e "AL_SSH_PORT=$AL_SSH_PORT" -e "AL_SSH_LISTEN=$AL_SSH_LISTEN")
  # proot-distro prints the session PID on stderr as "PID:     1234".
  out=$(al_login "${as[@]}" --detach -- andlinux-svc "$name" 2>&1)
  pid=$(awk '/^PID:/ {print $2}' <<<"$out")
  [[ -n "$pid" ]] || al_die "$name: could not start session: $out"
  mkdir -p "$AL_STATE_DIR/run"
  echo "$pid" >"$(_svc_pidfile "$name")"
  sleep 2
  if ! _svc_pid "$name" >/dev/null; then
    al_err "$name exited right away; last log lines:"
    tail -n 5 "$(_svc_log "$name")" 2>/dev/null | sed 's/^/      /' >&2
    return 1
  fi
  case $name in
    ssh) al_ok "ssh on ${AL_SSH_LISTEN}:${AL_SSH_PORT} (user $AL_USER); 'andlinux ip' shows the addresses" ;;
    code-server) al_ok "code-server on http://${AL_CODE_SERVER_LISTEN}:${AL_CODE_SERVER_PORT} (password in ~/.config/code-server/config.yaml)" ;;
  esac
}

_svc_stop() {
  local pid stopped=0
  while pid=$(_svc_pid "$1"); do
    proot-distro kill "$pid" >/dev/null 2>&1 || kill "$pid" 2>/dev/null || true
    rm -f "$(_svc_pidfile "$1")"
    stopped=1
    sleep 1
  done
  if ((stopped)); then al_ok "$1 stopped"; else al_info "$1 is not running"; fi
}

_svc_status() {
  local pid log
  log=$(_svc_log "$1")
  if pid=$(_svc_pid "$1"); then
    al_ok "$1: running (session $pid)"
  else
    al_info "$1: stopped"
  fi
  [[ -f "$log" ]] && tail -n 3 "$log" | sed 's/^/      /' >&2
  return 0
}

cmd_svc() {
  local action=${1:-status} target=${2:-all} s
  al_require_container
  [[ "$target" == all ]] && target=$AL_SERVICES
  for s in $target; do
    case $action in
      start)
        # "all" only starts what is installed and configured.
        if [[ "${2:-all}" == all ]] && ! (_svc_check "$s") >/dev/null 2>&1; then
          continue
        fi
        _svc_start "$s"
        ;;
      stop) _svc_stop "$s" ;;
      restart)
        _svc_stop "$s"
        _svc_start "$s"
        ;;
      status) _svc_status "$s" ;;
      *) al_die "usage: andlinux svc <start|stop|restart|status> [ssh|code-server|all]" ;;
    esac
  done
}
