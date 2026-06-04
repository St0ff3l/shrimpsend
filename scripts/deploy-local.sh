#!/usr/bin/env bash
# 本地调试一键部署：从 ops/local 同步配置并初始化 MySQL
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/sync-to-local.sh" "$@"
