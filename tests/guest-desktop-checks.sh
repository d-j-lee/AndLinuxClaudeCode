#!/usr/bin/env bash
# Runs inside the guest as the dev user: starts the AndLinux XFCE session on an
# Xvfb display (stand-in for Termux:X11) and checks the main desktop apps.
set -uo pipefail
export DISPLAY=:5
Xvfb :5 -screen 0 1280x720x24 >/tmp/xvfb.log 2>&1 &
sleep 3
andlinux-session >/tmp/session.log 2>&1 &
sleep 25
has() { xdotool search --class "$1" >/dev/null 2>&1; }
has xfce4-panel && echo PANEL_OK
has xfdesktop && echo DESKTOP_OK
pgrep -x fcitx5 >/dev/null && echo FCITX_OK
firefox --version
code --version | head -n1
(code --new-window >/tmp/code.log 2>&1 &)
(firefox about:blank >/tmp/firefox.log 2>&1 &)
(xfce4-terminal >/dev/null 2>&1 &)
sleep 30
has code && echo CODE_WINDOW_OK
has firefox && echo FIREFOX_WINDOW_OK
has xfce4-terminal && echo TERMINAL_WINDOW_OK
import -window root /tmp/andlinux-desktop.png && echo SHOT_OK
