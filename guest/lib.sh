# shellcheck shell=bash disable=SC2034
# Guest-side helpers (Ubuntu, run as root). Sourced after lib/common.sh.

export DEBIAN_FRONTEND=noninteractive
# Globals shared with the modules (hence SC2034 above).
G_APT_DIRTY=1 # the first apt call always refreshes the lists
G_ARCH=$(dpkg --print-architecture)
G_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
G_RELEASE=$(. /etc/os-release && echo "${VERSION_ID}")

g_apt() {
  al_retry 3 apt-get -q -y \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
    "$@"
}

g_apt_refresh() {
  if ((G_APT_DIRTY)); then
    # A stalled proxy/mobile connection can hang apt far beyond its own
    # timeouts (seen in testing); a watchdog plus retry recovers.
    al_retry 3 timeout 600 apt-get -q -y update
    G_APT_DIRTY=0
  fi
}

# g_pkg_installed PKG : true when PKG is installed.
g_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

# g_install PKG... : install only what is missing (no recommends).
g_install() {
  local -a missing=()
  local p
  for p in "$@"; do
    g_pkg_installed "$p" || missing+=("$p")
  done
  ((${#missing[@]})) || return 0
  g_apt_refresh
  g_apt install --no-install-recommends "${missing[@]}"
}

# g_install_rec PKG... : like g_install but with recommended packages.
g_install_rec() {
  local -a missing=()
  local p
  for p in "$@"; do
    g_pkg_installed "$p" || missing+=("$p")
  done
  ((${#missing[@]})) || return 0
  g_apt_refresh
  g_apt install "${missing[@]}"
}

# g_purge PKG... : remove packages that cannot work under proot.
g_purge() {
  local -a present=()
  local p
  for p in "$@"; do
    g_pkg_installed "$p" && present+=("$p")
  done
  ((${#present[@]})) || return 0
  g_apt purge "${present[@]}"
}

# g_pkg_available PKG : true when the apt index knows PKG.
g_pkg_available() {
  g_apt_refresh
  [[ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {print $2}')" ]]
}

# g_fetch URL DEST : download with retries.
g_fetch() {
  al_retry 3 curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$1"
}

# g_add_apt_repo NAME KEY_URL SOURCES_CONTENT
# Installs the vendor signing key under /etc/apt/keyrings (armored keys keep
# .asc, binary keys get .gpg) and writes /etc/apt/sources.list.d/NAME.sources.
# Use the literal @KEYRING@ in SOURCES_CONTENT for the key path.
g_add_apt_repo() {
  local name=$1 key_url=$2 content=$3 tmp keyring src
  install -d -m 0755 /etc/apt/keyrings
  tmp=$(mktemp)
  g_fetch "$key_url" "$tmp"
  if grep -q -- '-----BEGIN PGP PUBLIC KEY BLOCK-----' "$tmp"; then
    keyring=/etc/apt/keyrings/$name.asc
  else
    keyring=/etc/apt/keyrings/$name.gpg
  fi
  install -m 0644 "$tmp" "$keyring"
  rm -f "$tmp"
  src=/etc/apt/sources.list.d/$name.sources
  content=${content//@KEYRING@/$keyring}
  if [[ ! -f "$src" ]] || [[ "$(cat "$src")" != "$content" ]]; then
    printf '%s\n' "$content" >"$src"
    G_APT_DIRTY=1
  fi
}

g_user_home() {
  getent passwd "$AL_USER" | cut -d: -f6
}

# g_as_user CMD : run a bash command string as the dev user in a login shell.
g_as_user() {
  local home
  home=$(g_user_home)
  sudo -u "$AL_USER" -H env HOME="$home" USER="$AL_USER" LOGNAME="$AL_USER" \
    bash -lc "$1" 2> >(grep -v 'unable to send audit message' >&2)
}

# g_user_dir DIR... : create directories under the dev user's home, owned by
# the user all the way up (install -d -o only chowns the last component; proot
# hides that, a real kernel such as the AVF VM does not).
g_user_dir() {
  local home dir p
  home=$(g_user_home)
  for dir in "$@"; do
    mkdir -p "$dir"
    p=$dir
    while [[ "$p" == "$home"/* ]]; do
      chown "$AL_USER:$AL_USER" "$p"
      p=$(dirname "$p")
    done
  done
}

# g_user_file PATH MODE CONTENT : create a file owned by the dev user, but only
# when it does not exist yet (user changes always win).
g_user_file() {
  local path=$1 mode=$2 content=$3
  [[ -e "$path" ]] && return 0
  g_user_dir "$(dirname "$path")"
  printf '%s\n' "$content" >"$path"
  chown "$AL_USER:$AL_USER" "$path"
  chmod "$mode" "$path"
}

# g_template NAME : print guest/files/NAME with @VAR@ placeholders expanded
# from AL_* variables.
g_template() {
  local text var
  text=$(cat "$AL_GUEST_SRC/files/$1")
  while IFS= read -r var; do
    text=${text//@${var}@/${!var}}
  done < <(compgen -v AL_)
  printf '%s\n' "$text"
}

g_electron_wrapper() {
  # g_electron_wrapper NAME REAL_BINARY DESKTOP_FILE [EXTRA_FLAGS]
  # /usr/local/bin precedes /usr/bin in PATH, and /usr/local/share precedes
  # /usr/share in XDG_DATA_DIRS, so both shell and menu launches use these.
  local name=$1 real=$2 desktop=$3 extra=${4:-}
  cat >"/usr/local/bin/$name" <<EOF
#!/bin/sh
# andlinux: Chromium sandbox needs user namespaces, which proot lacks.
exec $real --no-sandbox $extra "\$@"
EOF
  chmod 0755 "/usr/local/bin/$name"
  if [[ -f "/usr/share/applications/$desktop" ]]; then
    install -d /usr/local/share/applications
    sed -E "s#^Exec=[^ ]+#Exec=/usr/local/bin/$name#" \
      "/usr/share/applications/$desktop" >"/usr/local/share/applications/$desktop"
  fi
}
