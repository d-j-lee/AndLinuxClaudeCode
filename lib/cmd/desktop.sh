# shellcheck shell=bash
# andlinux desktop [--detach] | --stop | --stop-all
# XFCE in the Ubuntu guest, drawn by the Termux:X11 app.

_x11_pidfile() { printf '%s/run/termux-x11.pid' "$AL_STATE_DIR"; }
_x11_socket() { printf '%s/tmp/.X11-unix/X%s' "$PREFIX" "${AL_DISPLAY#:}"; }

desktop_stop_x11() {
  local pidfile pid
  pidfile=$(_x11_pidfile)
  if [[ -f "$pidfile" ]]; then
    pid=$(<"$pidfile")
    kill "$pid" 2>/dev/null || true
    rm -f "$pidfile"
  fi
  # The X server runs as app_process inside Termux (com.termux.x11.CmdEntryPoint).
  pkill -f "com.termux.x11.CmdEntryPoint" 2>/dev/null || true
  pkill -f virgl_test_server 2>/dev/null || true
  rm -f "$(_x11_socket)"
}

desktop_start_audio() {
  al_have pulseaudio || return 0
  pulseaudio --check 2>/dev/null && return 0
  pulseaudio --start --exit-idle-time=-1 \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" ||
    al_warn "PulseAudio did not start; the desktop will have no sound"
}

cmd_desktop() {
  local detach=0
  case ${1:-} in
    --stop)
      desktop_stop_x11
      return 0
      ;;
    --stop-all)
      desktop_stop_x11
      proot-distro kill "$AL_CONTAINER" 2>/dev/null || true
      rm -f "$AL_STATE_DIR"/run/*.pid
      al_ok "stopped desktop and all '$AL_CONTAINER' sessions"
      return 0
      ;;
    --detach | -d) detach=1 ;;
    "") ;;
    *) al_die "usage: andlinux desktop [--detach|--stop|--stop-all]" ;;
  esac

  al_require_container
  al_have termux-x11 || al_die "termux-x11 is missing: run 'andlinux setup --profile desktop'"
  [[ -x "$(al_rootfs)/usr/bin/startxfce4" ]] ||
    al_die "XFCE is not installed in the guest: run 'andlinux setup --profile desktop'"

  mkdir -p "$AL_STATE_DIR/run"
  al_have termux-wake-lock && { timeout 10 termux-wake-lock || true; }
  desktop_stop_x11
  desktop_start_audio

  local -a session_env=(-e "DISPLAY=$AL_DISPLAY")
  if [[ "$AL_GPU" == virgl ]]; then
    if al_have virgl_test_server_android; then
      virgl_test_server_android --angle-gl >"$AL_STATE_DIR/logs/virgl.log" 2>&1 &
      session_env+=(-e GALLIUM_DRIVER=virpipe)
    else
      al_warn "AL_GPU=virgl but virglrenderer-android is missing; using software rendering"
    fi
  fi

  al_step "starting Termux:X11 on $AL_DISPLAY"
  mkdir -p "$AL_STATE_DIR/logs"
  # As documented upstream: start the server, then the proot session with
  # --shared-tmp (al_login always passes it) so clients find the socket.
  termux-x11 "$AL_DISPLAY" >"$AL_STATE_DIR/logs/termux-x11.log" 2>&1 &
  echo $! >"$(_x11_pidfile)"
  local _
  for _ in $(seq 1 50); do
    [[ -S "$(_x11_socket)" ]] && break
    sleep 0.2
  done
  [[ -S "$(_x11_socket)" ]] ||
    al_die "X server did not start (is the Termux:X11 app installed?); see $AL_STATE_DIR/logs/termux-x11.log"
  # Bring the Termux:X11 activity to the front.
  am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true

  al_step "starting XFCE (log out from the XFCE menu to end the session)"
  if ((detach)); then
    al_login --detach "${session_env[@]}" -- /usr/local/bin/andlinux-session
    return 0
  fi
  trap desktop_stop_x11 EXIT
  al_login "${session_env[@]}" -- /usr/local/bin/andlinux-session
}
