#!/usr/bin/env bash
# 启动本地开发环境：Centrifugo、后端、Web
# 用法:
#   ./scripts/start-dev.sh              # 国内逻辑（默认 Spring profile）
#   ./scripts/start-dev.sh --overseas   # 海外 ShrimpSend 逻辑（dev-overseas）
# 停止：./scripts/stop-dev.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/scripts/bin:$PATH"
PID_FILE="$ROOT/scripts/.dev-pids"
LOG_DIR="$ROOT/scripts/logs"
mkdir -p "$LOG_DIR"

OVERSEAS=false
for arg in "$@"; do
  case "$arg" in
    --overseas) OVERSEAS=true ;;
    *)
      echo "未知参数: $arg（支持: --overseas）" >&2
      exit 1
      ;;
  esac
done

if [ -f "$ROOT/backend/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
  set +a
fi

if [ "$OVERSEAS" = true ] && [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

# 与 config.json 中的 Centrifugo 密钥对齐（setup-local-config 可能已随机化 config.json）
if [ -f "$ROOT/config.json" ] && command -v python3 >/dev/null 2>&1; then
  eval "$(ROOT="$ROOT" python3 - <<'PY'
import json, os
from pathlib import Path
cfg = json.loads(Path(os.environ["ROOT"], "config.json").read_text())
print(f'export CENTRIFUGO_HTTP_API_KEY={cfg["http_api"]["key"]!r}')
print(f'export CENTRIFUGO_TOKEN_HMAC_SECRET={cfg["client"]["token"]["hmac_secret_key"]!r}')
PY
)"
fi

# 若已有进程，先尝试停止
if [ -f "$PID_FILE" ]; then
  echo "发现已有 .dev-pids，先执行 stop-dev.sh"
  "$ROOT/scripts/stop-dev.sh" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

if [ "$OVERSEAS" = true ]; then
  echo "模式: 海外本地 (Spring profile dev-overseas, DB ultrasend_overseas)"
else
  echo "模式: 国内本地 (默认 Spring profile, DB ultrasend)"
fi

echo "启动 Centrifugo (config.json)..."
centrifugo -c "$ROOT/config.json" >> "$LOG_DIR/centrifugo.log" 2>&1 &
echo $! >> "$PID_FILE"

echo "启动后端 (Spring Boot)..."
if [ "$OVERSEAS" = true ]; then
  (
    cd "$ROOT/backend"
    export SPRING_PROFILES_ACTIVE=dev-overseas
    exec ./gradlew bootRun
  ) >> "$LOG_DIR/backend.log" 2>&1 &
else
  (cd "$ROOT/backend" && exec ./gradlew bootRun) >> "$LOG_DIR/backend.log" 2>&1 &
fi
echo $! >> "$PID_FILE"

echo "等待后端 9000 端口..."
for i in {1..60}; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/auth/refresh 2>/dev/null | grep -q '401\|200'; then
    break
  fi
  sleep 1
done

echo "启动 Web (Next.js)..."
(cd "$ROOT/web" && exec npm run dev) >> "$LOG_DIR/web.log" 2>&1 &
echo $! >> "$PID_FILE"

echo ""
echo "本地服务已启动："
echo "  Centrifugo: http://localhost:8000"
echo "  后端 API:  http://localhost:9000"
echo "  Web:       http://localhost:3000"
echo ""
echo "日志: $LOG_DIR/ (centrifugo.log, backend.log, web.log)"
echo "停止: $ROOT/scripts/stop-dev.sh"
if [ "$OVERSEAS" = true ]; then
  echo ""
  echo "Stripe 本地 webhook（另开终端）:"
  echo "  stripe listen --forward-to localhost:9000/api/membership/stripe/webhook"
fi
