# shellcheck shell=bash
# Public tunnels for local services: cloudflared from Cloudflare's official
# repository (`andlinux tunnel PORT` uses its free quick tunnels).
# https://pkg.cloudflare.com/index.html

mod_hosting() {
  g_add_apt_repo cloudflare-main https://pkg.cloudflare.com/cloudflare-main.gpg \
"Types: deb
URIs: https://pkg.cloudflare.com/cloudflared
Suites: any
Components: main
Signed-By: @KEYRING@"
  g_install cloudflared
}
