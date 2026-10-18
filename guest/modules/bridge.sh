# shellcheck shell=bash
# Android integration: shared-storage shortcuts, Android-visible downloads and
# the android-open / android-share / android-clip helpers (installed from
# guest/bin by provision.sh).

mod_bridge() {
  local home dl
  home=$(g_user_home)
  g_install xdg-utils xdg-user-dirs

  # ~/Android  -> shared storage (/sdcard), when Termux has storage access
  # ~/Termux   -> the Termux home directory
  if [[ -d /sdcard ]]; then
    [[ -e "$home/Android" ]] || ln -s /sdcard "$home/Android"
  else
    al_warn "/sdcard is not visible: grant storage access (termux-setup-storage) and rerun setup"
  fi
  if [[ -n "${TERMUX_HOME:-}" && -d "$TERMUX_HOME" ]]; then
    [[ -e "$home/Termux" ]] || ln -s "$TERMUX_HOME" "$home/Termux"
  fi
  chown -h "$AL_USER:$AL_USER" "$home/Android" "$home/Termux" 2>/dev/null || true

  # Browser and app downloads land where Android's Files app shows them.
  dl=${AL_ANDROID_DOWNLOADS:-}
  if [[ -n "$dl" && -d "$dl" ]]; then
    g_user_file "$home/.config/user-dirs.dirs" 0644 "$(printf 'XDG_DOWNLOAD_DIR="%s"' "$dl")"
  fi
}
