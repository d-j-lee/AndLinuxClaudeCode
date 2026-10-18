# shellcheck shell=bash
# Build toolchain, Python, GitHub CLI (official repo) and mise (official repo)
# with the global runtimes from AL_MISE_TOOLS (Node LTS, uv by default).

mod_devtools() {
  g_install \
    build-essential pkg-config cmake make autoconf automake libtool \
    python3 python3-dev python3-venv python3-pip pipx python-is-python3 \
    sqlite3 libssl-dev zlib1g-dev libffi-dev

  # GitHub CLI: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
  g_add_apt_repo githubcli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
"Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $G_ARCH
Signed-By: @KEYRING@"

  # mise: https://mise.jdx.dev/installing-mise.html#apt
  g_add_apt_repo mise https://mise.jdx.dev/gpg-key.pub \
"Types: deb
URIs: https://mise.jdx.dev/deb
Suites: stable
Components: main
Architectures: $G_ARCH
Signed-By: @KEYRING@"

  g_install gh mise

  if [[ -n "${AL_MISE_TOOLS:-}" ]]; then
    al_info "mise use -g $AL_MISE_TOOLS"
    g_as_user "MISE_YES=1 mise use -g $AL_MISE_TOOLS && mise reshim"
  fi
  # Interactive shells also get mise's hooks (per-directory tool versions).
  # shellcheck disable=SC2016 # written verbatim into .bashrc
  al_write_managed_block "$(g_user_home)/.bashrc" andlinux-mise \
    'command -v mise >/dev/null && eval "$(mise activate bash)"'
  chown "$AL_USER:$AL_USER" "$(g_user_home)/.bashrc"
}
