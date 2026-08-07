#!/bin/sh
# Alpine/OpenRC oriented service control script
# Usage: ./services.sh start|stop|status

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

action=${1:-}
case "$action" in
  start|stop|status) ;;
  *) echo "Usage: $0 start|stop|status" >&2; exit 1 ;;
esac

log() { printf '%s %s\n' "$(date +%Y%m%d-%H:%M:%S)" "$*"; }
err() { log "$*" >&2; }

# Services to control. Ensure these correspond to /etc/init.d/<name> on Alpine.
services="v2ray nginx x-ui sing-box"

# helper to check if service script exists
service_exists() {
  svc="$1"
  if [ -x "/etc/init.d/$svc" ]; then
    return 0
  fi
  return 1
}

for svc in $services; do
  if ! service_exists "$svc"; then
    [ "$action" = "status" ] && log "$svc: not installed."
    continue
  fi

  case "$action" in
    start)
      # rc-service may print status; attempt start
      log "Starting $svc..."
      if rc-service "$svc" start 2>/dev/null; then
        log "$svc started."
      else
        err "ERROR: Failed to start $svc."
      fi
      ;;
    stop)
      log "Stopping $svc..."
      if rc-service "$svc" stop 2>/dev/null; then
        log "$svc stopped."
      else
        err "ERROR: Failed to stop $svc."
      fi
      ;;
    status)
      if rc-service "$svc" status >/dev/null 2>&1; then
        log "$svc: running."
      else
        log "$svc: not running."
      fi
      ;;
  esac
done
