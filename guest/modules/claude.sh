# shellcheck shell=bash disable=SC2016 # jq filters use $v literally
# Claude Code from Anthropic's official channels, plus user-level settings and
# a CLAUDE.md that tells Claude what this environment can and cannot do.

g_claude_native() {
  local home
  home=$(g_user_home)
  if [[ -x "$home/.local/bin/claude" ]]; then
    al_info "claude already installed (native; it updates itself)"
    return 0
  fi
  # https://code.claude.com/docs/en/setup : the installer refuses sudo, so it
  # runs as the dev user. It picks linux-arm64 (glibc) inside the guest.
  local target=
  [[ "$AL_CLAUDE_CHANNEL" == stable ]] && target=stable
  g_as_user "curl -fsSL https://claude.ai/install.sh | bash -s -- $target"
}

g_claude_apt() {
  local channel=${AL_CLAUDE_CHANNEL}
  # https://code.claude.com/docs/en/setup#install-with-linux-package-managers
  g_add_apt_repo claude-code https://downloads.claude.ai/keys/claude-code.asc \
"Types: deb
URIs: https://downloads.claude.ai/claude-code/apt/${channel}
Suites: ${channel}
Components: main
Signed-By: @KEYRING@"
  # Fingerprint published in the setup docs.
  if ! gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc 2>/dev/null |
    grep -q '^fpr:::::::::31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:'; then
    al_die "Claude Code signing key fingerprint mismatch"
  fi
  g_install claude-code
}

# g_json_set FILE JQ_FILTER VALUE : edit a JSON file in place ($v = VALUE).
g_json_set() {
  local tmp
  tmp=$(mktemp)
  jq --arg v "$3" "$2" "$1" >"$tmp" && cat "$tmp" >"$1"
  rm -f "$tmp"
}

g_claude_settings() {
  local home settings
  home=$(g_user_home)
  settings=$home/.claude/settings.json
  g_user_dir "$home/.claude"
  if [[ ! -f "$settings" ]]; then
    printf '{\n  "autoUpdatesChannel": "%s"\n}\n' "$AL_CLAUDE_CHANNEL" >"$settings"
  elif [[ "$AL_CLAUDE_METHOD" == native ]]; then
    g_json_set "$settings" '.autoUpdatesChannel = $v' "$AL_CLAUDE_CHANNEL"
  fi
  if [[ -n "${AL_CLAUDE_DEFAULT_MODE:-}" ]]; then
    case $AL_CLAUDE_DEFAULT_MODE in
      default | acceptEdits | plan | auto | dontAsk | bypassPermissions) ;;
      *) al_die "AL_CLAUDE_DEFAULT_MODE '$AL_CLAUDE_DEFAULT_MODE' is not a Claude Code permission mode" ;;
    esac
    g_json_set "$settings" '.permissions.defaultMode = $v' "$AL_CLAUDE_DEFAULT_MODE"
  fi
  chown "$AL_USER:$AL_USER" "$settings"

  al_write_managed_block "$home/.claude/CLAUDE.md" andlinux \
    "$(g_template claude-environment.md)" bottom md
  chown "$AL_USER:$AL_USER" "$home/.claude/CLAUDE.md"
}

mod_claude() {
  case $AL_CLAUDE_METHOD in
    native) g_claude_native ;;
    apt) g_claude_apt ;;
    *) al_die "AL_CLAUDE_METHOD must be native or apt, not '$AL_CLAUDE_METHOD'" ;;
  esac
  g_claude_settings
  g_as_user 'claude --version' || al_die "claude does not start"
}
