# shellcheck shell=bash
# Visual Studio Code from Microsoft's official APT repository, wrapped to run
# without the Chromium sandbox (it needs user namespaces) under proot.
# https://code.visualstudio.com/docs/setup/linux

mod_vscode() {
  local home
  echo 'code code/add-microsoft-repo boolean false' | debconf-set-selections
  g_add_apt_repo vscode https://packages.microsoft.com/keys/microsoft.asc \
"Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: @KEYRING@"
  g_install code
  # The package may also drop its own list file; keep a single source.
  rm -f /etc/apt/sources.list.d/vscode.list
  # bin/code is the CLI launcher (--install-extension etc.); it forwards the
  # flag to the Electron process it spawns.
  g_electron_wrapper code /usr/share/code/bin/code code.desktop
  g_electron_wrapper code-url-handler /usr/share/code/bin/code code-url-handler.desktop

  home=$(g_user_home)
  # No gnome-keyring under proot: store secrets in VS Code's basic store.
  g_user_file "$home/.vscode/argv.json" 0644 \
'{
  "password-store": "basic",
  "disable-hardware-acceleration": true
}'
  chown -R "$AL_USER:$AL_USER" "$home/.vscode"
}
