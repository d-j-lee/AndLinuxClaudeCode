# shellcheck shell=bash
# code-server: VS Code in a browser, for using the phone's environment from a
# PC or tablet. Official installer (it installs the arm64 .deb from GitHub
# releases); rerunning it upgrades. Started by `andlinux svc start code-server`.
# https://coder.com/docs/code-server/install

mod_code_server() {
  local home cfg
  if ! g_pkg_installed code-server; then
    local installer
    installer=$(mktemp)
    g_fetch https://code-server.dev/install.sh "$installer"
    sh "$installer" --method=detect
    rm -f "$installer"
  fi
  home=$(g_user_home)
  cfg=$home/.config/code-server/config.yaml
  if [[ ! -f "$cfg" ]]; then
    g_user_file "$cfg" 0600 "bind-addr: ${AL_CODE_SERVER_LISTEN}:${AL_CODE_SERVER_PORT}
auth: password
password: $(head -c 18 /dev/urandom | base64 | tr -d '/+=')
cert: false"
    al_info "code-server password: see $cfg"
  fi
  chown -R "$AL_USER:$AL_USER" "$home/.config/code-server"
}
