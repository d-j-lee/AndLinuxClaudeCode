# shellcheck shell=bash
# andlinux ip : addresses other devices can use to reach services here.

cmd_ip() {
  local out=""
  if al_have ip; then
    out=$(ip -o -4 addr show 2>/dev/null | awk '$2 != "lo" {sub("/.*", "", $4); print $2, $4}')
  fi
  if [[ -z "$out" ]] && al_have ifconfig; then
    out=$(ifconfig 2>/dev/null | awk '/^[a-z]/ {i=$1} /inet / && i != "lo:" {print i, $2}')
  fi
  if [[ -z "$out" ]] && al_have termux-wifi-connectioninfo; then
    out=$(timeout 8 termux-wifi-connectioninfo 2>/dev/null | awk -F'"' '/"ip"/ {print "wlan", $4}')
  fi
  [[ -n "$out" ]] || al_die "could not read network addresses"
  echo "Interfaces (Tailscale addresses start with 100.):"
  printf '  %s\n' "${out//$'\n'/$'\n'  }"
  echo
  echo "Services: ssh -p $AL_SSH_PORT $AL_USER@<address>   (andlinux svc start ssh)"
  echo "          http://<address>:<port> for dev servers bound to 0.0.0.0"
}
