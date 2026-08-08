#!/bin/sh
# Alpine/OpenRC friendly run script (POSIX sh)
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR" || { echo "Cannot cd to $SCRIPT_DIR" >&2; exit 1; }

log() { echo "$(date +%Y%m%d-%H:%M:%S) $*"; }
die() {
	log "$*" >&2
	exit 1
}

if [ "$(id -u)" -ne 0 ]; then
	die "This script must be run as root"
fi

# 仅依赖 jq（Alpine 官方包），其余全部用 BusyBox
command -v jq >/dev/null 2>&1 || die "jq could not be found. Please install jq (apk add jq)."

[ -f .env ] || die ".env not found. Please create a .env file."
set -a
# shellcheck disable=SC1091
. ./.env
set +a

# Validate required vars
: "${NIC:?NIC is not set in .env}"
: "${TX_BYTES_LIMIT:?TX_BYTES_LIMIT is not set in .env}"

# ---- 简单互斥锁（BusyBox 无 flock，用 mkdir 实现）----
LOCKDIR="$SCRIPT_DIR/.run.lock"
MAX_LOCK_AGE=120

acquire_lock() {
	if mkdir "$LOCKDIR" 2>/dev/null; then
		echo $$ >"$LOCKDIR/pid"
		trap 'rm -rf "$LOCKDIR"' EXIT
		return 0
	fi

	# 进程已死则清锁
	if [ -f "$LOCKDIR/pid" ]; then
		old_pid=$(cat "$LOCKDIR/pid" 2>/dev/null || echo "")
		if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
			log "Stale lock (pid $old_pid dead), removing."
			rm -rf "$LOCKDIR"
			if mkdir "$LOCKDIR" 2>/dev/null; then
				echo $$ >"$LOCKDIR/pid"
				trap 'rm -rf "$LOCKDIR"' EXIT
				return 0
			fi
		fi
	fi

	# 锁过期则强制清除（BusyBox date -r 读文件 mtime）
	if [ -d "$LOCKDIR" ]; then
		lock_mtime=$(date -r "$LOCKDIR" +%s 2>/dev/null || echo 0)
		now=$(date +%s)
		if [ "$lock_mtime" -gt 0 ] && [ $((now - lock_mtime)) -gt "$MAX_LOCK_AGE" ]; then
			log "Lock older than ${MAX_LOCK_AGE}s, force removing."
			rm -rf "$LOCKDIR"
			if mkdir "$LOCKDIR" 2>/dev/null; then
				echo $$ >"$LOCKDIR/pid"
				trap 'rm -rf "$LOCKDIR"' EXIT
				return 0
			fi
		fi
	fi

	return 1
}

if ! acquire_lock; then
	log "Another instance is still running, skipping this run."
	exit 0
fi

# 读取流量
if [ ! -r "/sys/class/net/${NIC}/statistics/tx_bytes" ]; then
	die "Cannot read tx_bytes for NIC=$NIC"
fi
NET_OUT=$(cat "/sys/class/net/${NIC}/statistics/tx_bytes")
NET_OUT=${NET_OUT:-0}

# 初始化 data.json
if [ ! -f data.json ]; then
	log "data.json not found. Creating a new one."
	jq -n --argjson now "$(date +%s)" --argjson current "$NET_OUT" \
		'{last_update: $now, current: $current, addup: 0}' >data.json
fi

LAST_UPDATE=$(jq -r '.last_update' data.json)
CURRENT=$(jq -r '.current' data.json)
ADD_UP=$(jq -r '.addup' data.json)

LAST_UPDATE=${LAST_UPDATE:-0}
CURRENT=${CURRENT:-0}
ADD_UP=${ADD_UP:-0}
TIME_NOW=$(date +%s)

# 判断是否跨天（BusyBox 支持 date -d @timestamp）
last_ymd=$(date -d "@$LAST_UPDATE" +%Y%m%d 2>/dev/null || echo "00000000")
today_ymd=$(date +%Y%m%d)

if [ "$last_ymd" != "$today_ymd" ]; then
	log "New day ($last_ymd -> $today_ymd), resetting addup and starting services."
	ADD_UP=0
	LAST_UPDATE=$TIME_NOW
	./services.sh start
fi

# 累计流量
if [ "$NET_OUT" -gt "$CURRENT" ]; then
	delta=$((NET_OUT - CURRENT))
	ADD_UP=$((ADD_UP + delta))
	log "Addup updated: +${delta} bytes (total: ${ADD_UP})."
else
	log "NET_OUT <= CURRENT, NIC may have restarted. Resetting current."
fi
CURRENT=$NET_OUT

# 超限停服务
if [ "$ADD_UP" -gt "$TX_BYTES_LIMIT" ]; then
	log "Traffic limit exceeded (${ADD_UP} > ${TX_BYTES_LIMIT}). Stopping services."
	./services.sh stop
fi

# 原子写回（BusyBox mktemp 支持 path/TEMPLATE.XXXXXX）
tmp=$(mktemp "$SCRIPT_DIR/data.json.XXXXXX")
jq --argjson last_update "$LAST_UPDATE" \
	--argjson current "$CURRENT" \
	--argjson addup "$ADD_UP" \
	'.last_update = $last_update | .current = $current | .addup = $addup' \
	data.json >"$tmp" && mv "$tmp" data.json

# 锁由 trap 在 EXIT 时清理

