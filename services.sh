#!/bin/sh
# Alpine/OpenRC oriented service control script
# Usage: ./services.sh start|stop|status

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR" || { echo "Cannot cd to $SCRIPT_DIR" >&2; exit 1; }

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

command -v rc-service >/dev/null 2>&1 || {
  err "rc-service not found (OpenRC required)"
  exit 1
}

# 要管理的服务（对应 /etc/init.d/ 下的名字）
services="v2ray nginx x-ui sing-box"

service_exists() {
  [ -x "/etc/init.d/$1" ]
}

is_running() {
  # OpenRC status 返回 0 表示 running
  rc-service "$1" status >/dev/null 2>&1
}

for svc in $services; do
  if ! service_exists "$svc"; then
    [ "$action" = "status" ] && log "$svc: not installed."
    continue
  fi

  case "$action" in
    start)
      if is_running "$svc"; then
        log "$svc: already running, skip."
        continue
      fi
      log "Starting $svc..."
      if rc-service "$svc" start >/dev/null 2>&1; then
        log "$svc started."
      else
        err "ERROR: Failed to start $svc."
      fi
      ;;
    stop)
      if ! is_running "$svc"; then
        log "$svc: already stopped, skip."
        continue
      fi
      log "Stopping $svc..."
      if rc-service "$svc" stop >/dev/null 2>&1; then
        log "$svc stopped."
      else
        err "ERROR: Failed to stop $svc."
      fi
      ;;
    status)
      if is_running "$svc"; then
        log "$svc: running."
      else
        log "$svc: not running."
      fi
      ;;
  esac
done
