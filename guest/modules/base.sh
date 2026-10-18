# shellcheck shell=bash disable=SC2034 # G_APT_DIRTY is read by guest/lib.sh
# Base system: official apt sources, current packages, locale, timezone and
# the everyday CLI toolbox.

g_base_mirror() {
  local src=/etc/apt/sources.list.d/ubuntu.sources
  [[ -n "${AL_UBUNTU_MIRROR:-}" && -f "$src" ]] || return 0
  # Point the main stanza at the mirror; keep security updates on the
  # official host so they are never delayed by mirror sync lag.
  awk -v m="$AL_UBUNTU_MIRROR" '
    /^URIs:/ { uri = NR; line = $0; next }
    /^Suites:/ {
      if (uri) { print ($0 ~ /-security/ ? line : "URIs: " m) }
      uri = 0; print; next
    }
    { if (uri) { print line; uri = 0 } print }
  ' "$src" >"$src.new"
  if ! cmp -s "$src" "$src.new"; then
    mv "$src.new" "$src"
    G_APT_DIRTY=1
    al_info "apt mirror: $AL_UBUNTU_MIRROR"
  else
    rm -f "$src.new"
  fi
}

g_base_classic_sudo() {
  # Ubuntu 25.10+ points the sudo alternative at sudo-rs, which has broken
  # under proot before (docs/decisions/0002-ubuntu-release.md). Classic sudo
  # ships alongside it. rust-coreutils is left alone on purpose: switching to
  # coreutils-from-gnu does not stick, because 26.04's build-essential depends
  # on coreutils-from-uutils and apt swaps it straight back (measured).
  local want=${AL_CLASSIC_SUDO:-auto}
  if [[ "$want" == auto ]]; then
    al_version_ge "$G_RELEASE" 25.10 && want=yes || want=no
  fi
  [[ "$want" == yes ]] || return 0
  g_install sudo
  # 26.04 ships both; the alternative defaults to sudo-rs (/usr/lib/cargo/bin).
  if [[ -e /usr/bin/sudo.ws ]] && update-alternatives --list sudo 2>/dev/null | grep -qx /usr/bin/sudo.ws; then
    update-alternatives --set sudo /usr/bin/sudo.ws >/dev/null 2>&1
  fi
}

g_base_locale() {
  local loc changed=0
  g_install locales
  for loc in $AL_LOCALES $AL_LANG; do
    if ! grep -qE "^${loc//./\\.}( |$)" /etc/locale.gen; then
      if grep -qE "^# *${loc//./\\.}( |$)" /etc/locale.gen; then
        sed -i -E "s/^# *(${loc//./\\.}( .*)?)$/\1/" /etc/locale.gen
      else
        echo "$loc ${loc#*.}" >>/etc/locale.gen
      fi
      changed=1
    fi
  done
  if ((changed)) || ! locale -a 2>/dev/null | grep -qi "^${AL_LANG%%.*}\.utf-\?8$"; then
    locale-gen >/dev/null
  fi
  update-locale LANG="$AL_LANG"
}

g_base_timezone() {
  local tz=${AL_TZ:-Asia/Seoul}
  g_install tzdata
  if [[ ! -e "/usr/share/zoneinfo/$tz" ]]; then
    al_warn "unknown timezone '$tz', using Asia/Seoul"
    tz=Asia/Seoul
  fi
  ln -sfn "/usr/share/zoneinfo/$tz" /etc/localtime
  echo "$tz" >/etc/timezone
}

g_base_tls() {
  local ca=/usr/local/share/ca-certificates/andlinux-extra.crt
  local tmp_conf=/etc/apt/apt.conf.d/00andlinux-bootstrap-ca
  if [[ -n "${AL_EXTRA_CA_FILE:-}" ]]; then
    [[ -r "$AL_EXTRA_CA_FILE" ]] || al_die "AL_EXTRA_CA_FILE not readable: $AL_EXTRA_CA_FILE"
    install -D -m 0644 "$AL_EXTRA_CA_FILE" "$ca"
    # Until ca-certificates builds the system bundle, point apt at the CA.
    [[ -s /etc/ssl/certs/ca-certificates.crt ]] ||
      printf 'Acquire::https::CAInfo "%s";\n' "$ca" >"$tmp_conf"
  fi
  if [[ "${AL_APT_HTTPS:-0}" == 1 && -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    if grep -q '^URIs: http://' /etc/apt/sources.list.d/ubuntu.sources; then
      sed -i 's#^URIs: http://#URIs: https://#' /etc/apt/sources.list.d/ubuntu.sources
      G_APT_DIRTY=1
    fi
  fi
  g_install apt-utils ca-certificates
  if [[ -f "$ca" ]]; then
    update-ca-certificates >/dev/null
    rm -f "$tmp_conf"
  fi
}

mod_base() {
  cat >/etc/apt/apt.conf.d/90andlinux <<'EOF'
// andlinux: flaky mobile networks
Acquire::Retries "3";
Acquire::http::Timeout "60";
Acquire::https::Timeout "60";
EOF
  g_base_mirror
  g_base_tls
  g_apt_refresh
  g_apt full-upgrade
  g_base_classic_sudo
  g_base_locale
  g_base_timezone
  g_install \
    apt-utils bash-completion bc bind9-dnsutils bzip2 ca-certificates curl file \
    fd-find git git-lfs gnupg htop iproute2 iputils-ping jq less lsof \
    nano ncdu netcat-openbsd openssh-client procps psmisc ripgrep rsync \
    sudo tmux tree unzip vim wget xz-utils zip zstd
  # Not installed: software-properties-common (add-apt-repository). It pulls
  # in ~100 packages incl. systemd, polkitd and packagekit, none of which can
  # run under proot; modules write deb822 sources directly instead.
  # Debian/Ubuntu ship fd as fdfind; give it the upstream name.
  [[ -e /usr/local/bin/fd ]] || ln -s /usr/bin/fdfind /usr/local/bin/fd
}
