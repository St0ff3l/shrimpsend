#!/usr/bin/env bash
# Android 打包：调用 build-android.sh，复制 arm64-v8a 产物到 app/dist/<version>/。
# 用法（在 Flutter 工程根目录 app/ 下）:
#   ./scripts/package_android.sh [--overseas] [--play] [--skip-build]
#   ./scripts/package_android.sh --all
#
# 参数:
#   --all         依次打出：国内 direct APK、出海 direct APK、出海 play AAB（规则与单包相同）
#   --overseas    出海包（intl）；默认国内（cn）（仅单包模式）
#   --play        Google Play 渠道（AAB）；默认 direct（APK，仅单包模式）
#   --skip-build  跳过 flutter build，仅复制已有产物（不可与 --all 同用）
#
# 所有变体：APK 为 --split-per-abi 的 arm64-v8a 拆分包（无 universal 总包）；
# versionCode 与 pubspec build-number 一致（Gradle 覆盖 Flutter 默认的 +2000 规则）。
#
# 产物（均在 app/dist/<x.y.z.b>/）:
#   Shrimpsend-android-cn-direct-arm64-v8a-<x.y.z.b>.apk
#   Shrimpsend-android-intl-direct-arm64-v8a-<x.y.z.b>.apk
#   Shrimpsend-android-intl-play-arm64-v8a-<x.y.z.b>.aab
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=package_common.sh
source "$APP_ROOT/scripts/package_common.sh"
cd "$APP_ROOT"

ALL=false
OVERSEAS=false
PLAY=false
SKIP_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --all) ALL=true ;;
    --overseas) OVERSEAS=true ;;
    --play) PLAY=true ;;
    --skip-build) SKIP_BUILD=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

package_assert_not_all_with_filters "$ALL" "$OVERSEAS" "$PLAY"
package_assert_all_no_skip_build "$ALL" "$SKIP_BUILD"

ANDROID_ABI="$(package_android_abi_slug)"

package_android_resolve_apk_src() {
  local apk_out_dir="$1"
  local dist_channel="$2"
  local version="$3"
  local candidate
  # 优先 Flutter 3.x 拆分包名 app-<abi>-<flavor>-release（约 60MB），避免误选 universal 总包（约 90MB+）
  for candidate in \
    "$apk_out_dir/app-${ANDROID_ABI}-${dist_channel}-release-${version}.apk" \
    "$apk_out_dir/app-${ANDROID_ABI}-${dist_channel}-release.apk" \
    "$apk_out_dir/app-${dist_channel}-${ANDROID_ABI}-release-${version}.apk" \
    "$apk_out_dir/app-${dist_channel}-${ANDROID_ABI}-release.apk" \
    "$apk_out_dir/Shrimpsend-android-${dist_channel}-${ANDROID_ABI}-${version}.apk" \
    "$apk_out_dir/Shrimpsend-android-${dist_channel}-${version}.apk"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

package_android_resolve_aab_src() {
  local bundle_out_dir="$1"
  local version="$2"
  local candidate
  for candidate in \
    "$bundle_out_dir/Shrimpsend-android-play-${ANDROID_ABI}-${version}.aab" \
    "$bundle_out_dir/Shrimpsend-android-play-${version}.aab" \
    "$bundle_out_dir/app-play-release-${version}.aab" \
    "$bundle_out_dir/app-play-release.aab"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

package_android_one() {
  local overseas="$1"
  local play="$2"
  local skip_build="$3"

  local dist_channel=direct
  if [[ "$play" == "true" ]]; then
    dist_channel=play
  fi

  local region
  region="$(package_region_slug "$overseas")"

  local version
  version="$(package_read_version "$APP_ROOT")"

  local dist_dir="$APP_ROOT/dist/$version"
  local build_kind=apk
  if [[ "$play" == "true" ]]; then
    build_kind=appbundle
  fi

  echo ""
  echo "==> Android package: region=$region channel=$dist_channel abi=$ANDROID_ABI format=$build_kind"

  if [[ "$skip_build" == "false" ]]; then
    if [[ "$overseas" == "true" ]]; then
      "$APP_ROOT/scripts/build-android.sh" --overseas "$build_kind" "$dist_channel"
    else
      "$APP_ROOT/scripts/build-android.sh" "$build_kind" "$dist_channel"
    fi
  fi

  local src=""
  local dist_artifact=""
  if [[ "$play" == "true" ]]; then
    local bundle_out_dir="$APP_ROOT/build/app/outputs/bundle/playRelease"
    dist_artifact="$dist_dir/Shrimpsend-android-${region}-play-${ANDROID_ABI}-${version}.aab"

    if ! src="$(package_android_resolve_aab_src "$bundle_out_dir" "$version")"; then
      echo "AAB (arm64-v8a) not found under: $bundle_out_dir" >&2
      exit 1
    fi
  else
    local apk_out_dir="$APP_ROOT/build/app/outputs/flutter-apk"
    dist_artifact="$dist_dir/Shrimpsend-android-${region}-${dist_channel}-${ANDROID_ABI}-${version}.apk"

    if ! src="$(package_android_resolve_apk_src "$apk_out_dir" "$dist_channel" "$version")"; then
      echo "APK (arm64-v8a) not found under: $apk_out_dir" >&2
      echo "Expected names like app-${dist_channel}-${ANDROID_ABI}-release.apk" >&2
      exit 1
    fi
  fi

  mkdir -p "$dist_dir"
  cp -f "$src" "$dist_artifact"
  echo "  <- $(basename "$src") ($(du -h "$src" | cut -f1))"
  echo "  -> $dist_artifact"
}

if [[ "$ALL" == "true" ]]; then
  echo "Android --all: cn/direct APK, intl/direct APK, intl/play AAB (arm64 split, pubspec versionCode)"
  package_android_one false false false
  package_android_one true false false
  package_android_one true true false
  echo ""
  echo "Done. All artifacts: $APP_ROOT/dist/$(package_read_version "$APP_ROOT")/"
else
  package_android_one "$OVERSEAS" "$PLAY" "$SKIP_BUILD"
  echo ""
  if [[ "$PLAY" == "true" ]]; then
    echo "Done. Build dir: $APP_ROOT/build/app/outputs/bundle/playRelease/"
  else
    echo "Done. Build dir: $APP_ROOT/build/app/outputs/flutter-apk/ (arm64-v8a only)"
  fi
fi
