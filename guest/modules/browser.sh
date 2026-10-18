# shellcheck shell=bash
# Firefox from Mozilla's official APT repository. Ubuntu's own firefox package
# is a snap shim, and snapd cannot run under proot.
# https://support.mozilla.org/kb/install-firefox-linux#w_install-firefox-deb-package-for-debian-based-distributions

mod_browser() {
  local home
  g_add_apt_repo mozilla https://packages.mozilla.org/apt/repo-signing-key.gpg \
"Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: @KEYRING@"
  # Mozilla's build must beat the snap shim, whose epoch sorts higher.
  printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
    >/etc/apt/preferences.d/mozilla
  g_install firefox
  if g_pkg_available firefox-l10n-ko && [[ "$AL_LANG" == ko_KR* ]]; then
    g_install firefox-l10n-ko
  fi
  update-alternatives --set x-www-browser /usr/bin/firefox >/dev/null 2>&1 || true

  home=$(g_user_home)
  g_user_file "$home/.config/xfce4/helpers.rc" 0644 'WebBrowser=firefox'
  chown -R "$AL_USER:$AL_USER" "$home/.config/xfce4"
}
