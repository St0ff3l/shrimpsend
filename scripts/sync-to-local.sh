#!/usr/bin/env bash
# 从 ops 仓同步本地调试配置到业务仓，并初始化 MySQL 库
# 用法（在业务仓根目录）:
#   ./scripts/sync-to-local.sh              # 同步配置 + 建库/迁移
#   ./scripts/sync-to-local.sh --skip-db    # 仅同步配置
#   ULTRASEND_OPS_DIR=/path/to/ops ./scripts/sync-to-local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/ops-common.sh
source "$ROOT/scripts/lib/ops-common.sh"
OPS_DIR="$(resolve_ultrasend_ops_dir "$ROOT")"
LOCAL_DIR="$OPS_DIR/local"
SKIP_DB=false

for arg in "$@"; do
  case "$arg" in
    --skip-db) SKIP_DB=true ;;
    -h|--help)
      echo "用法: $0 [--skip-db]"
      echo "  同步 ops/local/ 配置到业务仓，可选初始化 MySQL（ultrasend + ultrasend_overseas）"
      exit 0
      ;;
    *)
      echo "未知参数: $arg" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$LOCAL_DIR" ]; then
  echo "错误: ops/local 目录不存在: $LOCAL_DIR" >&2
  echo "请在 ops 仓创建 local/（见 ops/README.md 或 clone public-ops 到 ../ops）" >&2
  exit 1
fi

copy_file() {
  local src="$1"
  local dest="$2"
  if [ ! -f "$src" ]; then
    echo "  [跳过] 源文件不存在: $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "  $dest"
}

echo "==> 同步本地调试配置 from $LOCAL_DIR"

if [ -f "$LOCAL_DIR/config.json" ]; then
  copy_file "$LOCAL_DIR/config.json" "$ROOT/config.json"
fi

if [ -f "$LOCAL_DIR/application-dev-overseas.yml" ]; then
  copy_file \
    "$LOCAL_DIR/application-dev-overseas.yml" \
    "$ROOT/backend/src/main/resources/application-dev-overseas.yml"
fi

if [ -f "$LOCAL_DIR/backend.env" ]; then
  copy_file "$LOCAL_DIR/backend.env" "$ROOT/backend/.env"
fi

if [ -f "$LOCAL_DIR/docker.env" ]; then
  copy_file "$LOCAL_DIR/docker.env" "$ROOT/.env"
fi

if [ -f "$LOCAL_DIR/web/.env.local" ]; then
  copy_file "$LOCAL_DIR/web/.env.local" "$ROOT/web/.env.local"
elif [ -f "$OPS_DIR/web/.env.local" ]; then
  copy_file "$OPS_DIR/web/.env.local" "$ROOT/web/.env.local"
fi

# Flutter secrets（RevenueCat 公钥、生产 API/WS；local/flutter 可覆盖 ops/flutter）
if [ -f "$LOCAL_DIR/flutter/env.secrets.dart" ]; then
  copy_file "$LOCAL_DIR/flutter/env.secrets.dart" "$ROOT/app/lib/config/env.secrets.dart"
elif [ -f "$OPS_DIR/flutter/env.secrets.dart" ]; then
  copy_file "$OPS_DIR/flutter/env.secrets.dart" "$ROOT/app/lib/config/env.secrets.dart"
fi

if [ -f "$LOCAL_DIR/flutter/openpanel_env.secrets.dart" ]; then
  copy_file "$LOCAL_DIR/flutter/openpanel_env.secrets.dart" "$ROOT/app/lib/config/openpanel_env.secrets.dart"
elif [ -f "$OPS_DIR/flutter/openpanel_env.secrets.dart" ]; then
  copy_file "$OPS_DIR/flutter/openpanel_env.secrets.dart" "$ROOT/app/lib/config/openpanel_env.secrets.dart"
fi

if [ "$SKIP_DB" = true ]; then
  echo "==> 已跳过数据库初始化 (--skip-db)"
else
  echo "==> 初始化 MySQL 库"

  MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
  MYSQL_PORT="${MYSQL_PORT:-3306}"
  MYSQL_USER="${MYSQL_USER:-root}"
  MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

  if [ -f "$ROOT/backend/.env" ]; then
    # shellcheck disable=SC1090
    set -a
    source "$ROOT/backend/.env"
    set +a
    MYSQL_USER="${SPRING_DATASOURCE_USERNAME:-$MYSQL_USER}"
    MYSQL_PASSWORD="${SPRING_DATASOURCE_PASSWORD:-$MYSQL_PASSWORD}"
  fi

  mysql_exec() {
    local sql="$1"
    if command -v mysql >/dev/null 2>&1; then
      if [ -n "$MYSQL_PASSWORD" ]; then
        MYSQL_PWD="$MYSQL_PASSWORD" mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -e "$sql"
      else
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -e "$sql"
      fi
      return 0
    fi
    if command -v docker >/dev/null 2>&1 && docker compose -f "$ROOT/docker-compose.yml" ps mysql 2>/dev/null | grep -q 'Up'; then
      docker compose -f "$ROOT/docker-compose.yml" exec -T mysql \
        mysql -u"${MYSQL_USER:-root}" ${MYSQL_PASSWORD:+-p"$MYSQL_PASSWORD"} -e "$sql"
      return 0
    fi
    echo "  [警告] 未找到 mysql CLI，且 docker compose mysql 未运行；请手动建库：" >&2
    echo "    CREATE DATABASE ultrasend;" >&2
    echo "    CREATE DATABASE ultrasend_overseas;" >&2
    return 1
  }

  mysql_exec_file() {
    local file="$1"
    if command -v mysql >/dev/null 2>&1; then
      if [ -n "$MYSQL_PASSWORD" ]; then
        MYSQL_PWD="$MYSQL_PASSWORD" mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" < "$file"
      else
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" < "$file"
      fi
      return 0
    fi
    if command -v docker >/dev/null 2>&1 && docker compose -f "$ROOT/docker-compose.yml" ps mysql 2>/dev/null | grep -q 'Up'; then
      docker compose -f "$ROOT/docker-compose.yml" exec -T mysql \
        mysql -u"${MYSQL_USER:-root}" ${MYSQL_PASSWORD:+-p"$MYSQL_PASSWORD"} < "$file"
      return 0
    fi
    return 1
  }

  if ! mysql_exec "CREATE DATABASE IF NOT EXISTS ultrasend CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
    echo "  [警告] 无法连接 MySQL，请手动建库或稍后重试（可用 --skip-db 仅同步配置）" >&2
  else
    echo "  数据库 ultrasend 就绪"
    mysql_exec "CREATE DATABASE IF NOT EXISTS ultrasend_overseas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || true
    echo "  数据库 ultrasend_overseas 就绪"
    if [ -f "$ROOT/backend/scripts/schema.sql" ]; then
      mysql_exec_file "$ROOT/backend/scripts/schema.sql" && echo "  已执行 backend/scripts/schema.sql（ultrasend）"
    fi
  fi

  echo "  ultrasend_overseas 表结构将在首次 ./scripts/start-dev.sh --overseas 时由 JPA ddl-auto 创建"
  echo "  若从旧库升级，请手动对 ultrasend_overseas 执行 backend/scripts/migration-overseas-shrimpsend-upgrade.sql"
fi

echo ""
echo "==> 完成"
echo ""
echo "下一步（在业务仓根目录）:"
echo "  国内本地:  ./scripts/start-dev.sh"
echo "  海外本地:  ./scripts/start-dev.sh --overseas"
echo "  Stripe Webhook: stripe listen --forward-to localhost:9000/api/membership/stripe/webhook"
