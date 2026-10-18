# shellcheck shell=sh
# Managed by andlinux (guest/files/profile.sh); rerun `andlinux setup` instead
# of editing. Sourced by login shells and, through the hook at the top of
# /etc/bash.bashrc, by non-interactive bash too, so the desktop, `andlinux
# shell`, SSH sessions, IDE remotes and Claude Code's Bash tool all agree.

# proot has no PAM, so /etc/default/locale is never applied for us.
if [ -z "${LANG:-}" ] && [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG
fi

# Android runtime variables for Termux:API tools (termux-open, am, ...).
# `andlinux` sessions inherit them from Termux; SSH sessions get this copy.
if [ -z "${BOOTCLASSPATH:-}" ] && [ -r /etc/andlinux/android.env ]; then
  . /etc/andlinux/android.env
fi

: "${TERMUX_PREFIX:=/data/data/com.termux/files/usr}"
: "${TERMUX_HOME:=/data/data/com.termux/files/home}"
export TERMUX_PREFIX TERMUX_HOME

_al_path_prepend() {
  case ":$PATH:" in *":$1:"*) ;; *) [ -d "$1" ] && PATH="$1:$PATH" ;; esac
}
_al_path_append() {
  case ":$PATH:" in *":$1:"*) ;; *) [ -d "$1" ] && PATH="$PATH:$1" ;; esac
}
_al_path_prepend /usr/local/bin
_al_path_prepend "$HOME/.local/share/mise/shims"
_al_path_prepend "$HOME/.local/bin"
# Termux tools (termux-open, termux-clipboard-*, ...) last, so Ubuntu wins.
_al_path_append "$TERMUX_PREFIX/bin"
unset -f _al_path_prepend _al_path_append
export PATH

# Extra root CA (corporate TLS proxy): make every TLS stack trust it.
if [ -f /usr/local/share/ca-certificates/andlinux-extra.crt ]; then
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
  export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
  export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/andlinux-extra.crt
fi

# proot quirks: hard links are emulated (link2symlink), there is no sandbox
# support for Firefox, and PulseAudio lives on the Termux side.
export UV_LINK_MODE=copy
export MOZ_FAKE_NO_SANDBOX=1
export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
export NO_AT_BRIDGE=1

if command -v fcitx5 >/dev/null 2>&1; then
  export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
  export SDL_IM_MODULE=fcitx GLFW_IM_MODULE=ibus
fi

# Without a desktop, open URLs (for example Claude Code's login page) in the
# Android browser. The OAuth callback reaches localhost because proot shares
# the Android network namespace.
if [ -z "${DISPLAY:-}" ] && [ -z "${BROWSER:-}" ]; then
  export BROWSER=android-open
fi
