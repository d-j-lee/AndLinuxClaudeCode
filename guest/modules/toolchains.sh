# shellcheck shell=bash
# Extra language toolchains through mise (AL_MISE_TOOLS_FULL: Go, Java
# Temurin, Rust by default). Add more any time with `mise use -g TOOL@VER`.

mod_toolchains() {
  [[ -n "${AL_MISE_TOOLS_FULL:-}" ]] || return 0
  al_info "mise use -g $AL_MISE_TOOLS_FULL"
  g_as_user "MISE_YES=1 mise use -g $AL_MISE_TOOLS_FULL && mise reshim"
}
