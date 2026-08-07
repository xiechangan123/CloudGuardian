#!/bin/sh
# Alpine/OpenRC friendly run script (POSIX sh)
set -eu

log() { printf '%s %s\n' "$(date +%Y%m%d-%H:%M:%S)" "$*"; }
die() { log "$*" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  die "This script must be run as root"
fi

command -v jq >/dev/null 2>&1 || die "jq could not be found. Please install jq to run this script."

[ -f .env ] || die ".env not found. Please create a .env file."
# shellcheck disable=SC1091
set -a
. .env
set +a

: "${NIC:?NIC is not set in .env}"
: "${TX_BYTES_LIMIT:?TX_BYTES_LIMIT is not set in .env}"

# Simple lock using an atomic mkdir (works in containers and Alpine)
LOCKDIR="$(pwd)/.run.lock"
if mkdir "$LOCKDIR" 2>/dev/null; then
  trap 'rm -rf "$LOCKDIR"' EXIT
else
  log "Another instance is still running, skipping this run."
  exit 0
fi

NET_OUT=$(cat "/sys/class/net/${NIC}/statistics/tx_bytes" 2>/dev/null || printf '0')

# Initialize data.json if missing
if [ ! -f data.json ]; then
  log "data.json not found. Creating a new one."
  jq -n --argjson now "$(date +%s)" --argjson current "$NET_OUT" \
    '{last_update: $now, current: $current, addup: 0}' >data.json
fi

LAST_UPDATE=$(jq '.last_update' data.json)
TIME_NOW=$(date +%s)
CURRENT=$(jq '.current' data.json)
ADD_UP=$(jq '.addup' data.json)

# Compare by day number (portable, avoids GNU date -d)
last_day=$((LAST_UPDATE / 86400))
today_day=$((TIME_NOW / 86400))
if [ "$last_day" -ne "$today_day" ]; then
  log "New day, resetting addup and starting services."
  ADD_UP=0
  LAST_UPDATE=$TIME_NOW
  ./services.sh start
fi

# Update traffic delta (portable integer compare)
# Ensure variables are numeric
NET_OUT=${NET_OUT:-0}
CURRENT=${CURRENT:-0}
ADD_UP=${ADD_UP:-0}

if [ "$NET_OUT" -gt "$CURRENT" ]; then
  delta=$((NET_OUT - CURRENT))
  ADD_UP=$((ADD_UP + delta))
  log "Addup updated: +${delta} bytes (total: ${ADD_UP})."
else
  log "NET_OUT <= CURRENT, NIC may have restarted. Resetting current."
fi
CURRENT=$NET_OUT

# Stop services if limit exceeded
if [ "$ADD_UP" -gt "$TX_BYTES_LIMIT" ]; then
  log "Traffic limit exceeded (${ADD_UP} > ${TX_BYTES_LIMIT}). Stopping services."
  ./services.sh stop
fi

# Persist state
tmp=$(mktemp "$(pwd)/data.json.XXXXXX")
jq --argjson last_update "$LAST_UPDATE" \
  --argjson current "$CURRENT" \
  --argjson addup "$ADD_UP" \
  '.last_update = $last_update | .current = $current | .addup = $addup' \
  data.json >"$tmp" && mv "$tmp" data.json

# lockdir removed by trap on EXIT
