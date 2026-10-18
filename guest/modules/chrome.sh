# shellcheck shell=bash disable=SC2034 # G_APT_DIRTY is read by guest/lib.sh
# Google Chrome (official repository; arm64 builds since 2026) for web
# development and browser automation, wrapped with --no-sandbox for proot.
# https://www.google.com/linuxrepositories/

mod_chrome() {
  # Google's package re-creates google-chrome.list from a cron job; use the
  # same name and format so there is only ever one entry.
  install -d -m 0755 /etc/apt/keyrings
  g_fetch https://dl.google.com/linux/linux_signing_key.pub /etc/apt/keyrings/google-chrome.asc
  local line="deb [arch=$G_ARCH signed-by=/etc/apt/keyrings/google-chrome.asc] https://dl.google.com/linux/chrome/deb/ stable main"
  if [[ "$(cat /etc/apt/sources.list.d/google-chrome.list 2>/dev/null)" != "$line" ]]; then
    printf '%s\n' "$line" >/etc/apt/sources.list.d/google-chrome.list
    G_APT_DIRTY=1
  fi
  if ! g_pkg_available google-chrome-stable; then
    al_warn "google-chrome-stable is not available for $G_ARCH; skipping"
    return 0
  fi
  g_install google-chrome-stable
  g_electron_wrapper google-chrome-stable /usr/bin/google-chrome-stable google-chrome.desktop \
    '--disable-dev-shm-usage'
  ln -sfn /usr/local/bin/google-chrome-stable /usr/local/bin/google-chrome
}
