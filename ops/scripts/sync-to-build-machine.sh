#!/usr/bin/env bash
# 兼容入口：请使用业务仓 ./scripts/sync-to-build-machine.sh
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/scripts/sync-to-build-machine.sh" "$@"
