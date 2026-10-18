# shellcheck shell=bash
# andlinux backup : archive the container (rootfs incl. /home) to shared
# storage, which survives uninstalling Termux; optionally copy it with rclone.

cmd_backup() {
  local dir=$AL_BACKUP_DIR ext=tar.gz comp=gzip file keep=${AL_BACKUP_KEEP:-3}
  al_require_container
  if ! mkdir -p "$dir" 2>/dev/null; then
    al_warn "cannot write $dir (storage permission?); using $HOME/andlinux-backups"
    dir=$HOME/andlinux-backups
    mkdir -p "$dir"
  fi
  # proot-distro compresses with zstd when Python has compression.zstd (3.14+).
  if python3 -c 'import compression.zstd' 2>/dev/null; then
    ext=tar.zst comp=zstd
  fi
  file=$dir/$AL_CONTAINER-$(date +%Y%m%d-%H%M%S).$ext

  if proot-distro ps 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$AL_CONTAINER"; then
    al_warn "sessions are running; for a consistent backup run 'andlinux stop' first"
  fi
  al_step "backing up '$AL_CONTAINER' to $file"
  # Write to .part so an interrupted backup never looks complete.
  proot-distro backup "$AL_CONTAINER" --compress "$comp" --output "$file.part"
  mv "$file.part" "$file"
  [[ -f "$AL_USER_CONFIG" ]] && cp "$AL_USER_CONFIG" "$file.config.env"
  al_ok "$(du -h "$file" | cut -f1) written"

  # Keep the newest $keep archives.
  local -a old
  mapfile -t old < <(find "$dir" -maxdepth 1 -name "$AL_CONTAINER-*.tar.*" ! -name '*.config.env' \
    -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2- | tail -n +"$((keep + 1))")
  if ((${#old[@]})); then
    rm -f "${old[@]}" "${old[@]/%/.config.env}"
    al_info "removed ${#old[@]} older backup(s) (AL_BACKUP_KEEP=$keep)"
  fi

  if [[ -n "${AL_BACKUP_RCLONE_REMOTE:-}" ]]; then
    al_have rclone || al_die "AL_BACKUP_RCLONE_REMOTE is set but rclone is missing (andlinux setup installs it)"
    al_step "uploading to $AL_BACKUP_RCLONE_REMOTE"
    rclone copy --progress "$file" "$AL_BACKUP_RCLONE_REMOTE"
  fi
}
