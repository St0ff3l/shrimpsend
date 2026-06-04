#!/usr/bin/env bash
# Shared helpers for local dev scripts (sourced by start-dev.sh).

die() {
  echo "[错误] $*" >&2
  exit 1
}

cleanup_partial_start() {
  if [ -n "${ROOT:-}" ] && [ -f "$ROOT/scripts/stop-dev.sh" ]; then
    "$ROOT/scripts/stop-dev.sh" 2>/dev/null || true
  fi
}

# Print failure reason, tail log, stop partial stack, exit 1.
fail_and_cleanup() {
  local msg="$1"
  local logfile="${2:-}"
  echo "[错误] $msg" >&2
  if [ -n "$logfile" ] && [ -f "$logfile" ]; then
    echo "日志: $logfile" >&2
    echo "最后 15 行:" >&2
    tail -15 "$logfile" 2>/dev/null | sed 's/^/  /' >&2
  fi
  cleanup_partial_start
  exit 1
}

require_file() {
  local path="$1"
  local hint="$2"
  if [ ! -f "$path" ]; then
    die "$hint"
  fi
}

# Prints absolute path to centrifugo binary, or returns 1.
resolve_centrifugo_bin() {
  if [ -x "$ROOT/bin/centrifugo" ]; then
    echo "$ROOT/bin/centrifugo"
    return 0
  fi
  if [ -x "$ROOT/scripts/bin/centrifugo" ]; then
    echo "$ROOT/scripts/bin/centrifugo"
    return 0
  fi
  if command -v centrifugo >/dev/null 2>&1; then
    command -v centrifugo
    return 0
  fi
  return 1
}

# wait_service name pid timeout_seconds logfile mode
# mode: port_8000 | port_3000 | backend_refresh
# Returns 0 when ready, 1 on timeout or process exit.
wait_service() {
  local name="$1"
  local pid="$2"
  local timeout="$3"
  local logfile="$4"
  local mode="$5"
  local i ready=0

  printf "等待 %s 就绪" "$name"
  for i in $(seq 1 "$timeout"); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo ""
      return 1
    fi
    case "$mode" in
      port_8000)
        if curl -s -o /dev/null http://localhost:8000/ 2>/dev/null; then
          ready=1
        fi
        ;;
      port_3000)
        if curl -s -o /dev/null http://localhost:3000/ 2>/dev/null; then
          ready=1
        fi
        ;;
      backend_refresh)
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/auth/refresh 2>/dev/null | grep -q '401\|200'; then
          ready=1
        fi
        ;;
      *)
        echo ""
        echo "[错误] wait_service: 未知模式 $mode" >&2
        return 1
        ;;
    esac
    if [ "$ready" -eq 1 ]; then
      echo " OK (PID $pid)"
      return 0
    fi
    printf "."
    sleep 1
  done
  echo ""
  return 1
}

service_fail_reason() {
  local pid="$1"
  local timeout_msg="$2"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "进程已退出（PID $pid）"
  else
    echo "$timeout_msg"
  fi
}
