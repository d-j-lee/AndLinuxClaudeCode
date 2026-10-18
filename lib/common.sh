# shellcheck shell=bash
# Shared helpers for the Termux host side and the Ubuntu guest side.
# Sourced, never executed. Requires bash 4+.

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _al_c_reset=$'\e[0m' _al_c_dim=$'\e[2m' _al_c_red=$'\e[31m'
  _al_c_green=$'\e[32m' _al_c_yellow=$'\e[33m' _al_c_blue=$'\e[34m'
else
  _al_c_reset='' _al_c_dim='' _al_c_red='' _al_c_green='' _al_c_yellow='' _al_c_blue=''
fi

al_step() { printf '%s==>%s %s\n' "$_al_c_blue" "$_al_c_reset" "$*" >&2; }
al_info() { printf '    %s\n' "$*" >&2; }
al_ok()   { printf '%s ok%s %s\n' "$_al_c_green" "$_al_c_reset" "$*" >&2; }
al_warn() { printf '%swarn%s %s\n' "$_al_c_yellow" "$_al_c_reset" "$*" >&2; }
al_err()  { printf '%serror%s %s\n' "$_al_c_red" "$_al_c_reset" "$*" >&2; }
al_die()  { al_err "$*"; exit 1; }
al_dim()  { printf '%s%s%s\n' "$_al_c_dim" "$*" "$_al_c_reset" >&2; }

al_have() { command -v "$1" >/dev/null 2>&1; }

# al_retry ATTEMPTS CMD... : retry with exponential backoff (2s, 4s, 8s...).
al_retry() {
  local attempts=$1 delay=2 n=1
  shift
  until "$@"; do
    if ((n >= attempts)); then
      return 1
    fi
    al_warn "attempt $n/$attempts failed: $*; retrying in ${delay}s"
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
  done
}

# al_version_ge A B : true when version A >= version B.
al_version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# al_word_in WORD LIST : true when WORD is one of the space-separated LIST.
al_word_in() {
  local w
  for w in $2; do
    [[ "$w" == "$1" ]] && return 0
  done
  return 1
}

# al_load_env FILE : source a KEY=VALUE file if it exists. Only AL_* keys are
# honoured so that a stray line cannot clobber PATH or similar.
al_load_env() {
  local file=$1 line key
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    key=${line%%=*}
    key=${key//[[:space:]]/}
    [[ "$key" =~ ^AL_[A-Z0-9_]+$ ]] || {
      al_warn "ignoring non-AL_ line in $file: $line"
      continue
    }
    eval "export $key=${line#*=}"
  done <"$file"
}

# al_write_managed_block FILE MARKER CONTENT [bottom|top] [sh|md]
# Replace the block between ">>> MARKER >>>" and "<<< MARKER <<<" (or add it
# at the bottom/top of FILE) so reruns stay idempotent and user edits outside
# the block survive. "md" style wraps the markers in HTML comments.
al_write_managed_block() {
  local file=$1 marker=$2 content=$3 where=${4:-bottom} style=${5:-sh}
  local begin="# >>> ${marker} >>>" end="# <<< ${marker} <<<" rest block
  if [[ "$style" == md ]]; then
    begin="<!-- >>> ${marker} >>> -->" end="<!-- <<< ${marker} <<< -->"
  fi
  mkdir -p "$(dirname "$file")"
  [[ -e "$file" ]] || : >"$file"
  rest=$(awk -v b="$begin" -v e="$end" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file")
  # Trim blank lines at both ends of what is left.
  rest=$(printf '%s\n' "$rest" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')
  block=$(printf '%s\n%s\n%s' "$begin" "$content" "$end")
  if [[ -z "$rest" ]]; then
    printf '%s\n' "$block" >"$file"
  elif [[ "$where" == top ]]; then
    printf '%s\n\n%s\n' "$block" "$rest" >"$file"
  else
    printf '%s\n\n%s\n' "$rest" "$block" >"$file"
  fi
}
