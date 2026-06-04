#!/usr/bin/env bash
# Android 构建：默认国内（OVERSEAS_BUILD=false）；加 --overseas 为出海包。
# 用法（在 Flutter 工程根目录 app/ 下）:
#   ./scripts/build-android.sh [--overseas] [apk|appbundle|aab] [direct|play] [-- 其它 flutter 参数]
# play 渠道未指定构建类型时默认 appbundle；显式传入 apk 时仍打 APK。
# APK：--split-per-abi + 仅 arm64-v8a（体积小）；versionCode 由 Gradle 保持为 pubspec build-number。
# 从仓库根目录:
#   ./app/scripts/build-android.sh [--overseas] play
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_ROOT"

"$APP_ROOT/scripts/windows_font_assets.sh" disable

OVERSEAS=false
REMAINING=()
for arg in "$@"; do
  case "$arg" in
    --overseas) OVERSEAS=true ;;
    *) REMAINING+=("$arg") ;;
  esac
done

OVERSEAS_DEFINE=false
if [[ "$OVERSEAS" == "true" ]]; then
  OVERSEAS_DEFINE=true
fi

EXPLICIT_CMD=false
CMD=apk
if [[ ${#REMAINING[@]} -gt 0 ]]; then
  case "${REMAINING[0]}" in
    apk|appbundle|aab)
      EXPLICIT_CMD=true
      CMD="${REMAINING[0]}"
      REMAINING=("${REMAINING[@]:1}")
      ;;
  esac
fi

DIST="direct"
if [[ "${REMAINING[0]:-}" == "direct" || "${REMAINING[0]:-}" == "play" ]]; then
  DIST="${REMAINING[0]}"
  REMAINING=("${REMAINING[@]:1}")
fi

# Google Play 上架默认打 app bundle；显式传入 apk 时仍打 APK（本地调试等）
if [[ "$EXPLICIT_CMD" == "false" && "$DIST" == "play" ]]; then
  CMD=appbundle
fi

COMMON=(--release --flavor "$DIST" "--dart-define=OVERSEAS_BUILD=$OVERSEAS_DEFINE")
if [[ "$DIST" == "play" ]]; then
  COMMON+=(--dart-define=ANDROID_PLAY_DISTRIBUTION=true)
fi
DART_DEFINE_SECRETS=()
# shellcheck disable=SC1091
source "$APP_ROOT/scripts/dart-define-env-secrets.sh"
append_dart_define_secrets DART_DEFINE_SECRETS
COMMON+=("${DART_DEFINE_SECRETS[@]}")

# AAB 仅 arm64；APK 用 ABI 拆分（无 universal 总包），只打 arm64-v8a
ABI_FLAGS=(--target-platform android-arm64)
APK_FLAGS=(--split-per-abi "${ABI_FLAGS[@]}")

case "$CMD" in
  appbundle|aab)
    if ((${#REMAINING[@]})); then
      exec flutter build appbundle "${COMMON[@]}" "${ABI_FLAGS[@]}" "${REMAINING[@]}"
    else
      exec flutter build appbundle "${COMMON[@]}" "${ABI_FLAGS[@]}"
    fi
    ;;
  apk)
    if ((${#REMAINING[@]})); then
      exec flutter build apk "${COMMON[@]}" "${APK_FLAGS[@]}" "${REMAINING[@]}"
    else
      exec flutter build apk "${COMMON[@]}" "${APK_FLAGS[@]}"
    fi
    ;;
  *)
    echo "Unknown build command: $CMD (use apk, appbundle, or aab)" >&2
    exit 1
    ;;
esac
