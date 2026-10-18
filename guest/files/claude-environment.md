## Environment: AndLinux (Ubuntu under proot on Android)

This machine is an Android phone or tablet. Ubuntu runs in Termux through
proot-distro (container `@AL_CONTAINER@`, user `@AL_USER@`). proot translates
paths and fakes root; it is not a VM or a kernel container.

- No systemd, Docker, snap, FUSE, cgroups or user namespaces. Start services
  as background processes (`nohup … &` or tmux), not with `systemctl`.
  Use `apt` (with `sudo`, no password) and `mise` for runtimes.
- Every process runs as the Termux app's Android UID; `sudo` is not a security
  boundary. Claude Code's /sandbox cannot work here (needs bubblewrap).
- Networking is shared with Android: `localhost:PORT` opens in the phone's
  browser, `0.0.0.0:PORT` is reachable from the LAN/Tailscale. Ports below
  1024 cannot be bound. Prefer 3000-9999.
- Files: keep projects under `~/projects` (fast, POSIX). `~/Android` is shared
  storage (`/sdcard`): slow, no permissions/symlinks/exec bit; use it only to
  exchange files. `~/Termux` is the Termux home.
- Android helpers: `android-open URL|FILE`, `android-share FILE`,
  `android-clip copy|paste`.
- I/O-heavy work (npm install, big builds, file watchers) is several times
  slower than on a PC because every syscall goes through ptrace. Avoid
  unnecessary full rebuilds and recursive scans.
- Long-running processes die if Android kills Termux; save work often and
  commit to git.
