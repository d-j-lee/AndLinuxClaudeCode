# shellcheck shell=bash
# Korean fonts and Hangul input (fcitx5-hangul). Termux:X11 also passes
# composed text from the Android keyboard, but a hardware keyboard needs an
# X input method; fcitx5 handles both (docs/operations.md#한국어).

mod_korean() {
  local home qt6=fcitx5-frontend-qt6
  g_pkg_available "$qt6" || qt6=
  g_install \
    fonts-noto-cjk fonts-nanum fonts-noto-color-emoji \
    fcitx5 fcitx5-hangul fcitx5-config-qt fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 fcitx5-frontend-qt5 $qt6
  if [[ "$AL_LANG" == ko_KR* ]]; then
    g_install language-pack-ko language-pack-gnome-ko
  fi

  home=$(g_user_home)
  # Hangul key, Shift+Space and Ctrl+Space toggle Korean; US layout default.
  g_user_file "$home/.config/fcitx5/profile" 0644 \
'[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default'
  g_user_file "$home/.config/fcitx5/config" 0644 \
'[Hotkey/TriggerKeys]
0=Hangul
1=Shift+space
2=Control+space'
  # Ubuntu starts fcitx5 through im-config's Xsession.d hook, which the
  # Termux:X11 session never runs; let XFCE's autostart launch it instead.
  if [[ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]]; then
    g_user_file "$home/.config/autostart/org.fcitx.Fcitx5.desktop" 0644 \
      "$(cat /usr/share/applications/org.fcitx.Fcitx5.desktop)"
  fi
  chown -R "$AL_USER:$AL_USER" "$home/.config/fcitx5"
}
