#!/usr/bin/env bash
# 停止 start-dev 启动的本地进程。实现见 scripts/stop-dev.sh
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/scripts/stop-dev.sh" "$@"
