#!/usr/bin/env bash
# iOS 构建：默认国内（flavor cn）；加 --overseas 为国际包（flavor intl）。须在 macOS 上执行，并配置好 Xcode / 签名。
# Bundle ID：cn → dev.ultrasend.app.cn；intl → dev.ultrasend.app
# 用法（在 Flutter 工程根目录 app/ 下）:
#   ./scripts/build-ios.sh [--overseas] [--xcode-clean] [ipa|ios] [-- 其它 flutter 参数]
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_ROOT"

"$APP_ROOT/scripts/windows_font_assets.sh" disable

OVERSEAS=false
XCODE_CLEAN=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --overseas) OVERSEAS=true ;;
    --xcode-clean) XCODE_CLEAN=true ;;
    *) ARGS+=("$arg") ;;
  esac
done

FLAVOR=cn
OVERSEAS_DEFINE=false
if [[ "$OVERSEAS" == "true" ]]; then
  FLAVOR=intl
  OVERSEAS_DEFINE=true
  XCODE_CLEAN=true
fi

build_ios_xcode_clean() {
  local flavor="$1"
  local config="Release-${flavor}"
  local workspace="$APP_ROOT/ios/Runner.xcworkspace"
  echo "==> xcodebuild clean: scheme=$flavor configuration=$config"
  xcodebuild clean \
    -workspace "$workspace" \
    -scheme "$flavor" \
    -configuration "$config" \
    -quiet
}

# Fail fast when extra flutter args contradict script flavor / OVERSEAS_BUILD.
build_ios_assert_flavor_consistency() {
  local arg flavor_arg="" overseas_arg=""
  for arg in "$@"; do
    case "$arg" in
      --flavor)
        echo "错误: 请用 --overseas 切换 intl，不要手动传 --flavor（与 build-ios.sh 冲突）" >&2
        exit 1
        ;;
      --flavor=*)
        flavor_arg="${arg#--flavor=}"
        ;;
      --dart-define=OVERSEAS_BUILD=*)
        overseas_arg="${arg#--dart-define=OVERSEAS_BUILD=}"
        ;;
    esac
  done
  if [[ -n "$flavor_arg" && "$flavor_arg" != "$FLAVOR" ]]; then
    echo "错误: --flavor=$flavor_arg 与当前构建（flavor=$FLAVOR）不一致" >&2
    exit 1
  fi
  if [[ -n "$overseas_arg" && "$overseas_arg" != "$OVERSEAS_DEFINE" ]]; then
    echo "错误: OVERSEAS_BUILD=$overseas_arg 与当前构建（OVERSEAS_BUILD=$OVERSEAS_DEFINE）不一致" >&2
    exit 1
  fi
}

CMD="ipa"
if [[ "${ARGS[0]:-}" == "ipa" || "${ARGS[0]:-}" == "ios" ]]; then
  CMD="${ARGS[0]}"
  ARGS=("${ARGS[@]:1}")
fi

COMMON=(--release --flavor "$FLAVOR" "--dart-define=OVERSEAS_BUILD=$OVERSEAS_DEFINE")
DART_DEFINE_SECRETS=()
# shellcheck disable=SC1091
source "$APP_ROOT/scripts/dart-define-env-secrets.sh"
append_dart_define_secrets DART_DEFINE_SECRETS
COMMON+=("${DART_DEFINE_SECRETS[@]}")
if ((${#ARGS[@]})); then
  build_ios_assert_flavor_consistency "${ARGS[@]}"
fi

if [[ "$XCODE_CLEAN" == "true" ]]; then
  build_ios_xcode_clean "$FLAVOR"
fi

case "$CMD" in
  ipa)
    if ((${#ARGS[@]})); then
      flutter build ipa "${COMMON[@]}" "${ARGS[@]}"
    else
      flutter build ipa "${COMMON[@]}"
    fi
    ;;
  ios)
    if ((${#ARGS[@]})); then
      flutter build ios "${COMMON[@]}" "${ARGS[@]}"
    else
      flutter build ios "${COMMON[@]}"
    fi
    ;;
  *)
    echo "Unknown build command: $CMD (use ipa or ios)" >&2
    exit 1
    ;;
esac
