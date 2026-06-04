#!/usr/bin/env bash
# 仅启动海外逻辑后端（dev-overseas），不启 Centrifugo / Web。
# 全栈本地海外调试请用仓库根目录: ./scripts/start-dev.sh --overseas
#
# 数据库默认 localhost:3306/ultrasend_overseas（可用 OVERSEAS_DEV_DATASOURCE_* 覆盖）。
# Stripe：backend/.env 或根 .env 中配置 STRIPE_*，另开终端:
#   stripe listen --forward-to localhost:9000/api/membership/stripe/webhook
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [ -f "$ROOT/backend/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
  set +a
fi

export SPRING_PROFILES_ACTIVE=dev-overseas
exec ./gradlew bootRun
