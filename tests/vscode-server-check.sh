#!/usr/bin/env bash
# Runs inside the guest over SSH (tests/e2e-termux.sh), doing what VS Code
# Remote-SSH does on first connect: fetch the VS Code server for this CPU,
# unpack it under ~/.vscode-server and start it on a loopback port. The caller
# then reaches that port through an SSH local forward.
#
#   vscode-server-check.sh start PORT | stop
set -euo pipefail

dir=$HOME/.vscode-server-e2e
case ${1:-} in
  start)
    port=${2:?port}
    case $(uname -m) in
      aarch64) arch=arm64 ;;
      x86_64) arch=x64 ;;
      *) echo "unsupported arch" >&2; exit 1 ;;
    esac
    url=$(curl -fsSL "https://update.code.visualstudio.com/api/update/server-linux-$arch/stable/latest" |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["url"])')
    mkdir -p "$dir"
    curl -fsSL "$url" | tar -xz -C "$dir" --strip-components=1
    "$dir/bin/code-server" --version | head -n1
    nohup "$dir/bin/code-server" --host 127.0.0.1 --port "$port" \
      --without-connection-token --accept-server-license-terms >"$dir/server.log" 2>&1 &
    for _ in $(seq 1 60); do
      # The remote server answers 404 on "/"; /version is its health check.
      curl --noproxy '*' -fsS -o /dev/null "http://127.0.0.1:$port/version" 2>/dev/null &&
        { echo VSCODE_SERVER_UP; exit 0; }
      sleep 1
    done
    tail -n 20 "$dir/server.log" >&2
    exit 1
    ;;
  stop)
    pkill -f "$dir/node" 2>/dev/null || true
    rm -rf "$dir"
    ;;
  *)
    echo "usage: $0 start PORT | stop" >&2
    exit 2
    ;;
esac
