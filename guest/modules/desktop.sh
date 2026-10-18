# shellcheck shell=bash
# XFCE desktop for Termux:X11, trimmed of components that need logind,
# upower, polkit or a real session manager (none exist under proot).

mod_desktop() {
  local home
  g_install \
    xfce4 xfce4-terminal xfce4-whiskermenu-plugin xfce4-taskmanager \
    xfce4-screenshooter xfce4-notifyd xfce4-clipman-plugin thunar \
    thunar-archive-plugin mousepad ristretto file-roller \
    dbus-x11 x11-xserver-utils x11-utils xdg-utils at-spi2-core \
    adwaita-icon-theme fonts-dejavu-core \
    pulseaudio-utils pavucontrol
  # Left out on purpose: gvfs (+58 packages incl. udisks2, which cannot run
  # under proot; Thunar works without it, minus trash and network places) and
  # large icon themes such as papirus (114,320 files in the 24.04 package vs 874
  # for adwaita: minutes of unpacking under ptrace).
  # systemd itself is a hard dependency of XFCE on Ubuntu: installed, never run.
  # Screen lockers: the dev user has no password, so a lock screen is a trap.
  # (xscreensaver arrives as an alternative of xfce4-session's Recommends.)
  g_purge xfce4-power-manager xfce4-power-manager-plugins xfce4-screensaver \
    light-locker xscreensaver xscreensaver-data
  # Debian's alternatives would otherwise pick a random terminal.
  update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper >/dev/null 2>&1 || true

  home=$(g_user_home)
  # Compositing costs a lot with software rendering (llvmpipe).
  g_user_file "$home/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" 0644 \
'<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>'
  chown -R "$AL_USER:$AL_USER" "$home/.config"
}
