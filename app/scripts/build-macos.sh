#!/usr/bin/env bash
# macOS 构建：默认国内；加 --overseas 为出海包。
# 用法（在 Flutter 工程根目录 app/ 下）:
#   ./scripts/build-macos.sh [--overseas] [-- 其它 flutter 参数]
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_ROOT"

"$APP_ROOT/scripts/windows_font_assets.sh" disable

OVERSEAS=false
FLUTTER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --overseas) OVERSEAS=true ;;
    *) FLUTTER_ARGS+=("$arg") ;;
  esac
done

OVERSEAS_DEFINE=false
if [[ "$OVERSEAS" == "true" ]]; then
  OVERSEAS_DEFINE=true
fi

COMMON=(--release "--dart-define=OVERSEAS_BUILD=$OVERSEAS_DEFINE")
DART_DEFINE_SECRETS=()
# shellcheck disable=SC1091
source "$APP_ROOT/scripts/dart-define-env-secrets.sh"
append_dart_define_secrets DART_DEFINE_SECRETS
COMMON+=("${DART_DEFINE_SECRETS[@]}")
if ((${#FLUTTER_ARGS[@]})); then
  exec flutter build macos "${COMMON[@]}" "${FLUTTER_ARGS[@]}"
else
  exec flutter build macos "${COMMON[@]}"
fi
