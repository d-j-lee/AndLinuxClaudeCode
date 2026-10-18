# shellcheck shell=bash
# andlinux tunnel PORT : expose http://localhost:PORT at a temporary public
# https://*.trycloudflare.com URL (Cloudflare quick tunnel, no account).
# Quick tunnels have no uptime guarantee, a 200 in-flight request limit and no
# SSE support; for anything lasting use a named tunnel or Tailscale.

cmd_tunnel() {
  local port=${1:-}
  [[ "$port" =~ ^[0-9]+$ ]] || al_die "usage: andlinux tunnel PORT"
  al_require_container
  if [[ ! -x "$(al_rootfs)/usr/bin/cloudflared" ]]; then
    al_info "installing cloudflared (guest module 'hosting')"
    source "$AL_ROOT/lib/cmd/setup.sh"
    setup_guest hosting
  fi
  al_have termux-wake-lock && { timeout 10 termux-wake-lock || true; }
  al_step "tunnelling localhost:$port (Ctrl+C to stop); look for the trycloudflare.com URL"
  al_login -- cloudflared tunnel --no-autoupdate --url "http://localhost:$port"
}
